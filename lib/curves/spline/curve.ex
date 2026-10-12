defmodule Curves.Spline.Curve do
  @moduledoc ~s"""
  Struct representing a spline
  """
  alias Curves.Types, as: T
  alias Curves.Utils.{Arc, Percent, Poly, Segment, Vec}
  import Curves.Utils.Arc, only: [is_arc: 1]

  @minimum_u 0.0 - Curves.Utils.Constants.small_number()

  defstruct [
    :points,
    :segments,
    :transformations,
    :compressed,
    :type,
    :mod,
    :xmax,
    :xmin,
    :ymax,
    :ymin,
    :max_u,
    :scale,
    :rotation,
    lines: [],
    opts: [],
    origin: {0.0, 0.0}
  ]

  @typedoc ~s"""
  A spline. Its fields are internal and may change in any 1.x release,
  so use the functions in `Curves` (e.g. `Curves.solve/3`, `Curves.max_u/1`) instead of reading them.
  """
  @opaque t :: %__MODULE__{
            points: T.point_list(),
            segments: list(Segment.t()),
            transformations: list(),
            compressed: (u :: float(), opts :: T.opts() -> {:ok, T.point_tuple()}),
            max_u: float(),
            type: atom(),
            mod: module(),
            xmax: T.coord(),
            xmin: T.coord(),
            ymax: T.coord(),
            ymin: T.coord(),
            scale: float(),
            rotation: float(),
            lines: list(T.point_list()),
            opts: T.opts(),
            origin: T.point_tuple()
          }

  # Each spline type's define/2 prepares `coords` first (e.g. wrapping each point in a list),
  # so the shape of `coords` depends on the type.
  @doc false
  @spec define(list(list(T.point_tuple())), atom(), T.opts()) :: t()
  def define(coords, spline_type, opts \\ []) do
    mod = Curves.Spline.Type.get_mod(spline_type)
    {originx, originy} = Keyword.get(opts, :origin, {0.0, 0.0})

    segments =
      if mod.override_segment_parsing() do
        Enum.map(coords, &given_segment/1)
      else
        Segment.new_segments(coords)
      end

    points = mod.stored_points(coords)

    curve =
      struct(
        __MODULE__,
        Map.merge(Vec.bounds(points), %{
          type: spline_type,
          mod: mod,
          points: points,
          segments: segments,
          lines: mod.control_lines(coords),
          transformations: [],
          scale: 1.0,
          rotation: 0.0,
          max_u: length(segments) * 1.0,
          origin: Vec.new({originx, originy}),
          opts: opts
        })
      )

    # Each spline type can rebuild its segments first (e.g. Catmull-Rom adds the neighbouring knots).
    curve = %{curve | segments: segments |> Enum.with_index() |> mod.map_segments(curve)}

    {:ok, compressed} = compress(curve, opts)
    Map.put(curve, :compressed, compressed)
  end

  # A segment a spline type built itself: an arc as it is, or 4 points turned into floats.
  @spec given_segment(Arc.t() | list(T.point_tuple())) :: Segment.t()
  defp given_segment(arc) when is_arc(arc), do: arc
  defp given_segment(points), do: Enum.map(points, &Vec.new/1)

  @doc false
  @spec compress(__MODULE__.t(), opts :: list()) ::
          {:ok, (u :: float(), opts :: T.opts() -> {:ok, T.point_tuple()})} | {:error, any()}
  def compress(%__MODULE__{mod: mod} = curve, _opts \\ []) do
    curve = Curves.Transform.apply_all_transformations(curve)
    # Bounds of a transformed copy of the original points. `curve.points` itself is never changed.
    bounds =
      Percent.get_bounds_after_transforms(curve, fn ->
        Curves.Transform.transform_points(curve, curve.points)
      end)

    # What each segment needs for solving, worked out once: a polynomial's coefficients, or an
    # arc's centre and axes. A tuple, so solving can pick one by index.
    coefficients =
      curve.segments
      |> Enum.map(&prepare(&1, mod))
      |> List.to_tuple()

    {:ok,
     fn u, solve_opts ->
       {index, t} = Segment.split_u(u)
       point = coefficients |> elem(index) |> eval(t)
       {:ok, Percent.maybe_normalize(bounds, point, solve_opts)}
     end}
  end

  @spec prepare(Segment.t(), module()) :: tuple()
  defp prepare(arc, _mod) when is_arc(arc), do: Arc.prepare(arc)

  defp prepare(points, mod),
    do: Poly.coefficients(mod.blending_function(), points, mod.blending_factor())

  # Solves one prepared segment at t. Polynomials come first: they are the common case.
  @spec eval(tuple(), float()) :: T.point_tuple()
  defp eval(coefficients, t) when not is_arc(coefficients), do: Poly.eval(coefficients, t)
  defp eval(arc, t), do: Arc.eval(arc, t)

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

  # The same spline travelled the other way, so u = 0 is the old end. Every polynomial segment has 4
  # points that read the same backwards (a Bezier segment [p0, c0, c1, p1] backwards is
  # [p1, c1, c0, p0]; Catmull-Rom's [previous, k0, k1, next] becomes [next, k1, k0, previous]), and
  # an arc swaps its start and end angles. So it reverses the segments and each one.
  # Called by Curves.Transform.reverse/1.
  @doc false
  @spec reverse(t()) :: t()
  def reverse(curve) do
    curve = %{
      curve
      | segments: curve.segments |> Enum.reverse() |> Enum.map(&reverse_segment/1),
        points: Enum.reverse(curve.points)
    }

    {:ok, cb} = compress(curve)
    %{curve | compressed: cb}
  end

  @spec reverse_segment(Segment.t()) :: Segment.t()
  defp reverse_segment(arc) when is_arc(arc), do: Arc.reverse(arc)
  defp reverse_segment(points), do: Enum.reverse(points)

  # A transformed copy of the original points (knots or control points), for Curves.Svg
  # to draw. `curve.points` itself is never changed.
  @doc false
  @spec transformed_points(t()) :: T.point_list()
  def transformed_points(%__MODULE__{points: points} = curve) do
    curve
    |> Curves.Transform.apply_all_transformations()
    |> Curves.Transform.transform_points(points)
  end

  # The dashed lines Curves.Svg draws (see Curves.Spline.Type's control_lines/1), moved, scaled
  # and rotated like the curve.
  @doc false
  @spec control_lines(t()) :: list(T.point_list())
  def control_lines(%__MODULE__{lines: lines} = curve) do
    curve = Curves.Transform.apply_all_transformations(curve)
    Enum.map(lines, &Curves.Transform.transform_points(curve, &1))
  end

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
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, {:out_of_bounds, u}} -> raise Curves.Exceptions.OutOfBoundU, max: curve.max_u, u: u
    end
  end

  # n evenly spaced points by u, ending at max_u (u = 0 is not included).
  @doc false
  # Every u it asks for is within 0..max_u, so solving never fails and it always returns {:ok, _}.
  @spec take(t(), pos_integer(), T.opts()) :: {:ok, T.point_list()}
  def take(%{segments: segments} = curve, n, opts \\ []) do
    seg_count = length(segments)
    opts = resolve_opts(curve, opts)

    points =
      Enum.map(1..n, fn step ->
        # Multiply before dividing so the final step lands exactly on seg_count, not 3.0000000000000004.
        {:ok, point} = solve_resolved(curve, step * seg_count / n, opts)
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
end
