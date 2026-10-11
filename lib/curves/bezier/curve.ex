defmodule Curves.Bezier.Curve do
  @moduledoc ~s"""
  Struct representing a bezier curve.
  """
  alias Curves.Bezier.Predefined
  alias Curves.Types, as: T
  alias Curves.Utils.{Percent, Poly, Vec}

  # Blending matrices for 2, 3 and 4 points (linear, quadratic and cubic Bernstein polynomials).
  @matrices %{
    2 => [[1, 0], [-1, 1]],
    3 => [[1, 0, 0], [-2, 2, 0], [1, -2, 1]],
    4 => [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]
  }

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
    origin: {0.0, 0.0}
  ]

  @typedoc ~s"""
  A bezier curve. Its fields are internal and may change in any 1.x release,
  so use the functions in `Curves` (e.g. `Curves.solve/3`, `Curves.max_u/1`) instead of reading them.
  """
  @opaque t :: %__MODULE__{
            points: T.point_list(),
            xmax: T.coord(),
            xmin: T.coord(),
            ymax: T.coord(),
            ymin: T.coord(),
            scale: float(),
            rotation: float(),
            transformations: list(),
            compressed: (t :: float(), opts :: T.opts() ->
                           {:ok, T.point_tuple()} | {:error, tuple()}),
            opts: T.opts(),
            origin: T.point_tuple()
          }

  @doc false
  @spec define(T.point_list() | Predefined.curve_key(), T.opts()) :: t()
  def define(points, opts \\ [])

  def define([], _opts), do: raise(ArgumentError, "a bezier curve needs at least one point")

  def define(points, opts) do
    points =
      case points do
        k when is_atom(k) -> Predefined.get(k, opts)
        _ -> Enum.map(points, &Vec.new/1)
      end

    curve =
      struct(
        __MODULE__,
        Map.merge(Vec.bounds(points), %{
          points: points,
          transformations: [],
          scale: 1.0,
          rotation: 0.0,
          origin: Vec.new(Keyword.get(opts, :origin, {0.0, 0.0})),
          opts: opts
        })
      )

    {:ok, cb} = compress(curve, opts)
    Map.put(curve, :compressed, cb)
  end

  @doc false
  @spec compress(__MODULE__.t(), T.opts()) ::
          {:ok, (t :: float(), opts :: T.opts() -> {:ok, T.point_tuple()} | {:error, tuple()})}
          | {:error, atom()}
  def compress(curve, _opts \\ []) do
    %{points: points} = curve = Curves.Transform.apply_all_transformations(curve)
    compress_points(curve, points, length(points))
  end

  # The solving closure for a curve with `n` points. Errors are deferred to solve time,
  # so define/2 and transforms never crash on a bad point count.
  @spec compress_points(__MODULE__.t(), T.point_list(), non_neg_integer()) ::
          {:ok, (number(), T.opts() -> {:ok, T.point_tuple()} | {:error, tuple()})}
  defp compress_points(_curve, _points, n) when n < 2,
    do: {:ok, fn _t, _opts -> {:error, {:too_few_points, n, 2}} end}

  defp compress_points(_curve, _points, n) when n > 4,
    do: {:ok, fn _t, _opts -> {:error, {:too_many_points, n, 4}} end}

  defp compress_points(curve, points, n) do
    # Only the bounds and coefficients go into the closure, not the whole curve,
    # so closures don't hold on to older closures.
    bounds = Percent.get_bounds_after_transforms(curve, fn -> points end)
    coefficients = Poly.coefficients(Map.fetch!(@matrices, n), points)

    {:ok,
     fn t, solve_opts ->
       {:ok, Percent.maybe_normalize(bounds, Poly.eval(coefficients, t), solve_opts)}
     end}
  end

  # Adds a transformation such as {Curves.Transform.Move, :inc_x, [5]} to the end of the list,
  # then recompresses. Called by Curves.Transform, which can't touch this opaque struct itself.
  # The value of `field` (:origin, :scale or :rotation) before the change is stored with it.
  @doc false
  @spec add_transformation(t(), {module(), atom(), list()}, atom()) :: t()
  def add_transformation(curve, {mod, func, args}, field) do
    transformation = {mod, func, args, Map.fetch!(curve, field)}
    curve = %{curve | transformations: curve.transformations ++ [transformation]}
    {:ok, cb} = compress(curve)
    %{curve | compressed: cb}
  end

  # The curve's points after moving, scaling and rotating, for Curves.Svg to draw.
  @doc false
  @spec transformed_points(t()) :: T.point_list()
  def transformed_points(curve) do
    %{points: points} = Curves.Transform.apply_all_transformations(curve)
    points
  end

  @doc false
  @spec solve(t(), number(), T.opts()) :: {:ok, T.point_tuple()} | {:error, tuple()}
  def solve(%__MODULE__{} = curve, t, opts) when is_number(t),
    do: solve_resolved(curve, t, resolve_opts(curve, opts))

  # Solves with opts that already went through resolve_opts/2, so take/3 can resolve them
  # once for every point instead of once per point.
  @spec solve_resolved(__MODULE__.t(), number(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, tuple()}
  defp solve_resolved(_curve, t, _opts) when t < 0.0 or t > 1.0, do: {:error, {:out_of_bounds, t}}
  defp solve_resolved(%{compressed: compressed}, t, opts), do: compressed.(t, opts)

  # Reads :force_percent once per solve or take call (see Opts.put_force_percent/2).
  @spec resolve_opts(__MODULE__.t(), T.opts()) :: T.opts()
  defp resolve_opts(curve, opts), do: Curves.Utils.Opts.put_force_percent(curve.opts, opts)

  # Raises the matching Curves.Exceptions error instead of returning {:error, _}.
  @doc false
  @spec solve!(t(), number(), T.opts()) :: T.point_tuple()
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, err} -> raise_error(err)
    end
  end

  # n evenly spaced points, at t = 1/n, 2/n, ... 1.0 (t = 0 is not included).
  @doc false
  @spec take(t(), pos_integer(), T.opts()) :: {:ok, T.point_list()} | {:error, tuple()}
  def take(curve, n, opts \\ []) do
    opts = resolve_opts(curve, opts)

    Enum.reduce_while(1..n, [], fn i, acc ->
      # i / n, not i * (1 / n): the rounding in 1 / n would make the last t 0.9999999999999999
      # for some n (e.g. 49) instead of exactly 1.0.
      case solve_resolved(curve, i / n, opts) do
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
  @spec take!(t(), pos_integer(), T.opts()) :: T.point_list()
  def take!(curve, n, opts \\ []) do
    case take(curve, n, opts) do
      {:ok, points} -> points
      {:error, err} -> raise_error(err)
    end
  end

  # Turns an {:error, reason} from solve/take into the matching Curves.Exceptions error.
  @spec raise_error(tuple()) :: no_return()
  defp raise_error({:too_few_points, n, min}),
    do: raise(Curves.Exceptions.TooFewPoints, n: n, min: min)

  defp raise_error({:too_many_points, n, max}),
    do: raise(Curves.Exceptions.TooManyPoints, n: n, max: max)

  defp raise_error({:out_of_bounds, t}), do: raise(Curves.Exceptions.OutOfBoundT, t: t)
end
