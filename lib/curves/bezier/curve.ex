defmodule Curves.Bezier.Curve do
  @moduledoc ~s"""
  Struct representing a bezier curve.
  """
  alias Curves.Utils.{Point, Points}
  alias Curves.Utils.Types, as: T
  alias Curves.Bezier.{Linear, Quadratic}
  alias Curves.Bezier.Predefined

  defstruct [
    :points,
    :xmax,
    :xmin,
    :ymax,
    :ymin,
    :scale,
    :transformations,
    :compressed,
    opts: [],
    origin: Nx.tensor([0.0, 0.0])
  ]

  @typedoc ~s"""
  | field  	| description                                    	|
  |--------	|------------------------------------------------	|
  | `:points` 	| A tensor representing 2D points                	|
  | `:xmax`   	| the highest x coord in the tensor              	|
  | `:xmin`   	| the lowest x coord in the tensor               	|
  | `:ymin`   	| the lowest y coord in the tensor               	|
  | `:ymax`   	| the highest y coord in the tensor              	|
  | `:origin` 	| the origin of the graph.                       	|
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
    transformations: list(),
    compressed: (t :: float(), opts :: T.opts() -> T.point_tuple()),
    opts: T.opts(),
    origin: Nx.Tensor.t()
  }

  @doc false
  def define(points, opts \\ []) do
    {originx, originy} = Keyword.get(opts, :origin, {0.0, 0.0})
    points = case points do
      k when is_atom(k) -> Predefined.get(k, opts)
      _ -> points
    end
      |> Points.new_points(opts)

    curve = struct(__MODULE__, %{
      points: points,
      ymin: Nx.reduce_min(points[dimension: 1]) |> Nx.to_number(),
      ymax: Nx.reduce_max(points[dimension: 1]) |> Nx.to_number(),
      xmin: Nx.reduce_min(points[dimension: 0]) |> Nx.to_number(),
      xmax: Nx.reduce_max(points[dimension: 0]) |> Nx.to_number(),
      transformations: [],
      scale: 1.0,
      origin: Point.new_point({originx, originy}, opts),
      opts: opts
    })

    {:ok, cb} = compress(curve, opts)
    Map.put(curve, :compressed, cb)
  end


  @spec compress(__MODULE__.t(), T.opts()) :: {:ok, (t :: float(), opts :: T.opts() -> {:ok, T.point_tuple()} | {:error, tuple()})} | {:error, atom()}
  def compress(%{opts: curve_opts} = curve, opts \\ []) do
    opts = 
      curve_opts
      |> Keyword.merge(opts)
      |> Curves.Utils.Opts.merge_opts()

    %{points: points} = Curves.Transform.apply_all_transformations(curve)
    {_, size} = Nx.shape(points)

    case size do
      n when n < 2 -> {:error, {:too_few_points, n, 2}}

      2 ->
        {:ok, fn t, _opts -> {:ok, Linear.get_linear_interpolation_point(points, t) |> Point.to_tuple()} end}

      3 ->
        {:ok, fn t, _opts -> {:ok, Quadratic.get_quadratic_point(points, t) |> Point.to_tuple()} end}

      4 ->
        {:ok, fn t, solve_opts -> {:ok, Curves.Formula.run(Curves.Formula.CubicBezier, points, t, Keyword.merge(opts, solve_opts)) |> Point.to_tuple()} end}

      n when n > 4 ->
        {:ok, fn t, solve_opts -> {:ok, Curves.Formula.run(Curves.Formula.CubicBezier, points, t, Keyword.merge(opts, solve_opts)) |> Point.to_tuple()} end}
    end
  end

  @doc false
  def solve(curve, t), do: solve(curve, t, [])

  @doc false
  def solve(%__MODULE__{compressed: compressed} = curve, t, opts) when is_number(t) do
    cond do
      (t < 0.0 or t > 1.0) -> {:error, {:out_of_bounds, t}}
      true ->
        case compressed.(t, opts) do
          {:ok, point} -> {:ok, force_percent(curve, point, opts)}
          err -> err
        end
  end
  end

  @doc false
  def solve!(curve, t), do: solve!(curve, t, [])

  @doc false
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, {:too_few_points, n, min}} ->  raise Curves.Exceptions.TooFewPoints, n: n, min: min
      {:error, {:out_of_bounds, t}} ->  raise Curves.Exceptions.OutOfBoundT, t: t
    end
  end

  @doc false
  def take(curve, n, opts \\ []) do
    Enum.reduce_while(1..n, [], fn i, acc ->
      case solve(curve, i * (1 / n), opts) do
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
      {:error, {:too_few_points, n, min}} ->  raise Curves.Exceptions.TooFewPoints, n: n, min: min
      {:error, {:out_of_bounds, t}} ->  raise Curves.Exceptions.OutOfBoundT, t: t
    end
  end

  defp to_perc(curve, coord, dimension) when is_float(coord) do
    {min, max} = case dimension do
      :x -> {curve.xmin, curve.xmax}
      :y -> {curve.ymin, curve.ymax}
    end
    denominator = max - min
    if denominator == 0, do: max, else: (coord - min) / denominator
  end

  defp force_percent(curve, point, opts) do
    if !Keyword.get(opts, :force_percent) do
      point
    else
      {x, y} = point
      {to_perc(curve, x, :x), to_perc(curve, y, :y)}
    end
  end
end
