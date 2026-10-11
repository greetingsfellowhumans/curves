defmodule Curves.Bezier.Curve do
  @moduledoc ~s"""
  Struct representing a bezier curve.
  """
  alias Curves.Bezier.{Linear, Quadratic}
  alias Curves.Bezier.Predefined
  alias Curves.Utils.{Percent, Point, Points}
  alias Curves.Utils.TensorTypes, as: TensorT
  alias Curves.Utils.Types, as: T

  defstruct [
    :points,
    :xmax,
    :xmin,
    :ymax,
    :ymin,
    :scale,
    :transformations,
    :rotation,
    :compressed,
    opts: [],
    origin: Nx.tensor([0.0, 0.0])
  ]

  @typedoc ~s"""
  | field  	| description                                    	|
  |--------	|------------------------------------------------	|
  | `:points` 	| A tensor representing 2D points                	|
  | `:xmax`   	| the highest x coord in the tensor, before any transforms	|
  | `:xmin`   	| the lowest x coord in the tensor, before any transforms	|
  | `:ymin`   	| the lowest y coord in the tensor, before any transforms	|
  | `:ymax`   	| the highest y coord in the tensor, before any transforms	|
  | `:origin` 	| the origin of the graph.                       	|
  | `:rotation` 	| the degrees by which the curve is rotated.   	|
  | `:transformations` 	| The list of transformations applied to this curve.                       	|
  | `:compressed` 	| A preprocessed function for fast solving.                       	|
  | `:opts`   	| The keyword list of options                    	|
  """
  @type t :: %__MODULE__{
          points: Nx.Tensor.t(),
          xmax: T.coord(),
          xmin: T.coord(),
          ymax: T.coord(),
          ymin: T.coord(),
          scale: float(),
          rotation: float(),
          transformations: list(),
          compressed: (t :: float(), opts :: T.opts() -> T.point_tuple()),
          opts: T.opts(),
          origin: Nx.Tensor.t()
        }

  @doc false
  def define(points, opts \\ []) do
    {originx, originy} = Keyword.get(opts, :origin, {0.0, 0.0})

    points =
      case points do
        k when is_atom(k) -> Predefined.get(k, opts)
        _ -> points
      end
      |> Points.new_points(opts)

    curve =
      struct(__MODULE__, %{
        points: points,
        ymin: Nx.reduce_min(points[dimension: 1]) |> Nx.to_number(),
        ymax: Nx.reduce_max(points[dimension: 1]) |> Nx.to_number(),
        xmin: Nx.reduce_min(points[dimension: 0]) |> Nx.to_number(),
        xmax: Nx.reduce_max(points[dimension: 0]) |> Nx.to_number(),
        transformations: [],
        scale: 1.0,
        rotation: 0.0,
        origin: Point.new_point({originx, originy}, opts),
        opts: opts
      })

    {:ok, cb} = compress(curve, opts)
    Map.put(curve, :compressed, cb)
  end

  @spec compress(__MODULE__.t(), T.opts()) ::
          {:ok, (t :: float(), opts :: T.opts() -> {:ok, T.point_tuple()} | {:error, tuple()})}
          | {:error, atom()}
  def compress(%{opts: curve_opts} = curve, opts \\ []) do
    opts =
      curve_opts
      |> Keyword.merge(opts)
      |> Curves.Utils.Opts.merge_opts()

    %{points: points} = curve = Curves.Transform.apply_all_transformations(curve)
    {_, size} = Nx.shape(points)

    case size do
      # Errors are deferred to solve-time so that define/2 and transforms never crash on a bad point count.
      n when n < 2 ->
        {:ok, fn _t, _opts -> {:error, {:too_few_points, n, 2}} end}

      2 ->
        bounds = get_bounds(curve)

        {:ok,
         fn t, solve_opts ->
           Linear.get_linear_interpolation_point(points, t) |> to_result(bounds, solve_opts)
         end}

      3 ->
        bounds = get_bounds(curve)

        {:ok,
         fn t, solve_opts ->
           Quadratic.get_quadratic_point(points, t) |> to_result(bounds, solve_opts)
         end}

      4 ->
        bounds = get_bounds(curve)

        {:ok,
         fn t, solve_opts ->
           Curves.Formula.run(
             Curves.Formula.CubicBezier,
             points,
             t,
             Keyword.merge(opts, solve_opts)
           )
           |> to_result(bounds, solve_opts)
         end}

      n when n > 4 ->
        {:ok, fn _t, _opts -> {:error, {:too_many_points, n, 4}} end}
    end
  end

  @doc false
  def solve(curve, t), do: solve(curve, t, [])

  @doc false
  def solve(%__MODULE__{} = curve, t, opts) when is_number(t),
    do: solve_resolved(curve, t, resolve_opts(curve, opts))

  # Solves with opts that already went through resolve_opts/2, so take/3 can resolve them
  # once for every point instead of once per point.
  @spec solve_resolved(__MODULE__.t(), number(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, tuple()}
  defp solve_resolved(_curve, t, _opts) when t < 0.0 or t > 1.0, do: {:error, {:out_of_bounds, t}}
  defp solve_resolved(%{compressed: compressed}, t, opts), do: compressed.(t, opts)

  # Reads :force_percent once per solve or take call, so a change to the app config after define still applies.
  # Precedence: opts passed to solve, then opts passed to define, then app config, then the default.
  @spec resolve_opts(__MODULE__.t(), T.opts()) :: T.opts()
  defp resolve_opts(curve, opts) do
    force_percent =
      Keyword.merge(curve.opts, opts)
      |> Curves.Utils.Opts.merge_opts()
      |> Keyword.get(:force_percent)

    Keyword.put(opts, :force_percent, force_percent)
  end

  # Bounds of the transformed points, for :force_percent. Only the 2-, 3- and 4-point branches call it,
  # so curves with a bad point count never crash at define. Only the bounds go into the closures,
  # not the whole curve, so closures don't hold on to older closures.
  @spec get_bounds(__MODULE__.t()) :: Percent.bounded()
  defp get_bounds(%{points: points} = curve),
    do: Percent.get_bounds_after_transforms(curve, fn -> points end)

  # Turns a solved point tensor into {:ok, {x, y}}, rescaled when :force_percent is on.
  @spec to_result(TensorT.point(), Percent.bounded(), T.opts()) :: {:ok, T.point_tuple()}
  defp to_result(point, bounds, solve_opts),
    do: {:ok, Percent.maybe_normalize(bounds, Point.to_tuple(point), solve_opts)}

  @doc false
  def solve!(curve, t), do: solve!(curve, t, [])

  @doc false
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, err} -> raise_error(err)
    end
  end

  @doc false
  def take(curve, n, opts \\ []) do
    opts = resolve_opts(curve, opts)

    Enum.reduce_while(1..n, [], fn i, acc ->
      case solve_resolved(curve, i * (1 / n), opts) do
        {:ok, point} -> {:cont, [point | acc]}
        {:error, term} -> {:halt, term}
      end
    end)
    |> case do
      li when is_list(li) -> {:ok, Enum.reverse(li)}
      err -> {:error, err}
    end
  end

  @doc false
  def take!(curve, n, opts \\ []) do
    case take(curve, n, opts) do
      {:ok, points} -> points
      {:error, err} -> raise_error(err)
    end
  end

  defp raise_error({:too_few_points, n, min}),
    do: raise(Curves.Exceptions.TooFewPoints, n: n, min: min)

  defp raise_error({:too_many_points, n, max}),
    do: raise(Curves.Exceptions.TooManyPoints, n: n, max: max)

  defp raise_error({:out_of_bounds, t}), do: raise(Curves.Exceptions.OutOfBoundT, t: t)
end
