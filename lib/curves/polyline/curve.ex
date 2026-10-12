defmodule Curves.Polyline.Curve do
  @moduledoc ~s"""
  Struct representing a polyline: knots joined by straight lines, like SVG's `<polyline>`.

  ```elixir
  curve = Curves.define_polyline([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])

  # Find any point along it (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw it as an SVG image
  Curves.Svg.save!(curve, "polyline.svg")
  ```

  ![Polyline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/polyline.svg)

  Like a spline, it is solved with `u`: each straight line (segment) adds one to it, so `u = 1.0` is the
  second knot and `Curves.max_u/1` is the last one. Within a segment the speed is steady, so `u = 1.5`
  is exactly halfway between the second and third knots.
  """
  alias Curves.Types, as: T
  alias Curves.Utils.{Percent, Segment, Vec}

  @minimum_u 0.0 - Curves.Utils.Constants.small_number()

  defstruct [
    :points,
    :xmax,
    :xmin,
    :ymax,
    :ymin,
    :max_u,
    :scale,
    :rotation,
    :transformations,
    :compressed,
    opts: [],
    origin: {0.0, 0.0}
  ]

  @typedoc ~s"""
  A polyline. Its fields are internal and may change in any 1.x release,
  so use the functions in `Curves` (e.g. `Curves.solve/3`, `Curves.max_u/1`) instead of reading them.
  """
  @opaque t :: %__MODULE__{
            points: T.point_list(),
            xmax: T.coord(),
            xmin: T.coord(),
            ymax: T.coord(),
            ymin: T.coord(),
            max_u: float(),
            scale: float(),
            rotation: float(),
            transformations: list(),
            compressed: (u :: float(), opts :: T.opts() -> {:ok, T.point_tuple()}),
            opts: T.opts(),
            origin: T.point_tuple()
          }

  @doc false
  @spec define(T.point_list(), T.opts()) :: t()
  def define(knots, opts \\ [])

  def define([], _opts), do: raise(ArgumentError, "a polyline needs at least 1 point, got none")

  def define(knots, _opts) when not is_list(knots) do
    raise ArgumentError, "a polyline takes a list of {x, y} points, got: #{inspect(knots)}"
  end

  def define(knots, opts) do
    points = Enum.map(knots, &Vec.new/1)

    curve =
      struct(
        __MODULE__,
        Map.merge(Vec.bounds(points), %{
          points: points,
          max_u: (length(points) - 1) * 1.0,
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

  # Builds the solving closure from the moved, scaled and rotated knots. Only the bounds and the
  # knots go into it, not the whole curve, so closures don't hold on to older closures.
  @doc false
  @spec compress(t(), T.opts()) :: {:ok, (float(), T.opts() -> {:ok, T.point_tuple()})}
  def compress(curve, _opts \\ []) do
    %{points: points} = curve = Curves.Transform.apply_all_transformations(curve)
    bounds = Percent.get_bounds_after_transforms(curve, fn -> points end)
    knots = List.to_tuple(points)

    {:ok,
     fn u, solve_opts -> {:ok, Percent.maybe_normalize(bounds, at(knots, u), solve_opts)} end}
  end

  # The point at `u`: `t` of the way along segment `index`, between knots `index` and `index + 1`.
  # A single knot has no segments, so it is always that knot.
  @spec at(tuple(), float()) :: T.point_tuple()
  defp at({knot}, _u), do: knot

  defp at(knots, u) do
    {index, t} = Segment.split_u(u)
    between(elem(knots, index), elem(knots, index + 1), t)
  end

  @spec between(T.point_tuple(), T.point_tuple(), float()) :: T.point_tuple()
  defp between({ax, ay}, {bx, by}, t), do: {mix(ax, bx, t), mix(ay, by, t)}

  # The value `t` of the way from `a` to `b`. Written as a * (1 - t) + b * t (not a + t * (b - a)),
  # so t = 0.0 and t = 1.0 give the knots exactly. When a and b are the same, that formula can be
  # off in the last digit (e.g. 100000.0 gives 99999.99999999999), which would make a flat line or a
  # single point look very slightly bent, so equal values are returned as they are.
  @spec mix(float(), float(), float()) :: float()
  defp mix(a, b, _t) when a == b, do: a
  defp mix(a, b, t), do: a * (1 - t) + b * t

  @doc false
  @spec solve(t(), number(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, {:out_of_bounds, number()}}
  def solve(%__MODULE__{} = curve, u, opts) when is_number(u),
    do: solve_resolved(curve, u, resolve_opts(curve, opts))

  def solve(_curve, u, _opts),
    do: raise(ArgumentError, "u must be a number, got: #{inspect(u)}")

  # Solves with opts that already went through resolve_opts/2, so take/3 can resolve them
  # once for every point instead of once per point.
  @spec solve_resolved(t(), number(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, {:out_of_bounds, number()}}
  defp solve_resolved(%{max_u: max}, u, _opts) when u > max or u < @minimum_u,
    do: {:error, {:out_of_bounds, u}}

  defp solve_resolved(%{compressed: cb}, u, opts), do: cb.(u * 1.0, opts)

  # Reads :force_percent once per solve or take call (see Opts.put_force_percent/2).
  @spec resolve_opts(t(), T.opts()) :: T.opts()
  defp resolve_opts(curve, opts), do: Curves.Utils.Opts.put_force_percent(curve.opts, opts)

  @doc false
  @spec solve!(t(), number(), T.opts()) :: T.point_tuple()
  def solve!(curve, u, opts) do
    case solve(curve, u, opts) do
      {:ok, point} -> point
      {:error, {:out_of_bounds, u}} -> raise Curves.Exceptions.OutOfBoundU, max: curve.max_u, u: u
    end
  end

  # n evenly spaced points by u, ending at max_u (u = 0 is not included).
  # Every u it asks for is within 0..max_u, so solving never fails and it always returns {:ok, _}.
  @doc false
  @spec take(t(), pos_integer(), T.opts()) :: {:ok, T.point_list()}
  def take(%{max_u: max_u} = curve, n, opts \\ []) do
    opts = resolve_opts(curve, opts)

    points =
      Enum.map(1..n, fn step ->
        # Multiply before dividing so the final step lands exactly on max_u.
        {:ok, point} = solve_resolved(curve, step * max_u / n, opts)
        point
      end)

    {:ok, points}
  end

  @doc false
  @spec take!(t(), pos_integer(), T.opts()) :: T.point_list()
  def take!(curve, n, opts \\ []) do
    {:ok, points} = take(curve, n, opts)
    points
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

  # The polyline with every point moved by `fun` (an affine map), applied as it is drawn: its own
  # moves, scaling and rotation are folded into its points first. See Curves.Spline.Curve.map_points/2.
  @doc false
  @spec map_points(t(), (T.point_tuple() -> T.point_tuple())) :: t()
  def map_points(curve, fun) do
    points = curve |> transformed_points() |> Enum.map(fun)

    curve =
      struct(
        curve,
        Map.merge(Vec.bounds(points), %{
          points: points,
          transformations: [],
          scale: 1.0,
          rotation: 0.0,
          origin: {0.0, 0.0}
        })
      )

    {:ok, cb} = compress(curve)
    %{curve | compressed: cb}
  end

  # The same polyline travelled the other way: its knots in reverse order, so u = 0 is the old end.
  # Called by Curves.Transform.reverse/1. Transforms still apply on top, as before.
  @doc false
  @spec reverse(t()) :: t()
  def reverse(curve) do
    curve = %{curve | points: Enum.reverse(curve.points)}
    {:ok, cb} = compress(curve)
    %{curve | compressed: cb}
  end

  # The knots after moving, scaling and rotating, for Curves.Svg to draw.
  @doc false
  @spec transformed_points(t()) :: T.point_list()
  def transformed_points(curve) do
    %{points: points} = Curves.Transform.apply_all_transformations(curve)
    points
  end

  # A polyline has no control points, so Curves.Svg draws no dashed lines for it.
  @doc false
  @spec control_lines(t()) :: list(T.point_list())
  def control_lines(_curve), do: []
end
