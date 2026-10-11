defmodule Curves.Utils.Segment do
  @moduledoc false
  # A segment is a list of 4 points, [knot0, cp0, cp1, knot1]: the shape every spline type is
  # solved in. Each spline type decides what the 4 points mean (e.g. Catmull-Rom uses
  # [previous knot, knot0, knot1, next knot]); its blending matrix turns them into a curve.
  alias Curves.Types, as: T
  alias Curves.Utils.Vec

  # Exactly 4 points.
  @type t() :: list(T.point_tuple())

  # One point of a bezier spline, checked and turned into floats: its knot and the 0 to 2
  # control points of the curve from this knot to the next one.
  @typep parsed_point() :: {T.point_tuple(), list(T.point_tuple())}

  # Builds cubic segments from a bezier spline's points, the way SVG path data works: each point
  # is a knot plus the control points of the curve to the next knot, and the next point's knot
  # ends that curve. [knot] is a straight line (SVG L), [knot, c] a quadratic curve (SVG Q) and
  # [knot, c0, c1] a cubic curve (SVG C). Lines and quadratics are turned into the exact same
  # curve written as a cubic, so every segment has 4 points.
  # The last point only ends the curve, so it must be [knot]. A single knot is one segment that
  # stays on that point. Coordinates are turned into floats.
  @spec new_segments(list(list(T.point_tuple()))) :: list(t())
  def new_segments([]), do: raise(ArgumentError, "a spline needs at least 1 point, got none")

  def new_segments(lists) do
    lists
    |> parse_points()
    |> to_segments()
  end

  # The dashed lines Curves.Svg draws for a bezier spline: from each control point to the knot
  # it pulls the curve towards (see handle_lines/3). Takes the same points as new_segments/1.
  @spec control_lines(list(list(T.point_tuple()))) :: list(T.point_list())
  def control_lines(lists) do
    lists
    |> parse_points()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [{knot, controls}, {next, _}] -> handle_lines(knot, controls, next) end)
  end

  # The lines from a curve's control points to the knots they pull on, e.g. for SVG's C
  # (start, c0, c1, end) that is start to c0 and c1 to end. A quadratic's one control pulls on
  # both ends, so it is start to c to end. A straight line has no control points, so no lines.
  @spec handle_lines(T.point_tuple(), T.point_list(), T.point_tuple()) :: list(T.point_list())
  def handle_lines(_start, [], _finish), do: []
  def handle_lines(start, [c], finish), do: [[start, c, finish]]
  def handle_lines(start, [c0, c1], finish), do: [[start, c0], [c1, finish]]

  # Checks every point's shape and that the last one has no control points.
  @spec parse_points(list(term())) :: list(parsed_point())
  defp parse_points(lists) do
    parsed = Enum.map(lists, &parse_point/1)
    check_last(List.last(parsed), List.last(lists))
    parsed
  end

  @spec check_last(parsed_point(), term()) :: :ok
  defp check_last({_knot, []}, _given), do: :ok

  defp check_last(_parsed, given) do
    raise ArgumentError,
          "the last point of a bezier spline only ends the curve, so it must be [knot], " <>
            "got: #{inspect(given)}. Control points belong to the point before the curve they shape. " <>
            "See Curves.define_bezier_spline/2."
  end

  @spec to_segments(list(parsed_point())) :: list(t())
  defp to_segments([{knot, []}]), do: [[knot, knot, knot, knot]]

  defp to_segments(points) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{knot, controls}, {next, _}] -> cubic(knot, controls, next) end)
  end

  # The same curve as a cubic. A line gets control points a third and two thirds of the way
  # along, so it is also travelled at a steady speed. A quadratic with control point c gets
  # control points two thirds of the way from each end towards c (exact degree elevation).
  @spec cubic(T.point_tuple(), T.point_list(), T.point_tuple()) :: t()
  defp cubic(start, [], finish),
    do: [start, towards(start, finish, 1 / 3), towards(start, finish, 2 / 3), finish]

  defp cubic(start, [c], finish),
    do: [start, towards(start, c, 2 / 3), towards(finish, c, 2 / 3), finish]

  defp cubic(start, [c0, c1], finish), do: [start, c0, c1, finish]

  # The point `fraction` of the way from `a` to `b`.
  @spec towards(T.point_tuple(), T.point_tuple(), float()) :: T.point_tuple()
  defp towards(a, b, fraction), do: Vec.add(a, Vec.scale(Vec.subtract(b, a), fraction))

  @spec parse_point(term()) :: parsed_point()
  defp parse_point([knot | controls] = point) when length(point) in 1..3,
    do: {Vec.new(knot), Enum.map(controls, &Vec.new/1)}

  # Anything else is a malformed input to define_bezier_spline/2, e.g. a plain {x, y} instead of [{x, y}].
  defp parse_point(other) do
    raise ArgumentError,
          "each point of a bezier spline must be a list of 1 to 3 {x, y} tuples: " <>
            "[knot], [knot, control_point] or [knot, control_point0, control_point1]. " <>
            "Got: #{inspect(other)}. See Curves.define_bezier_spline/2."
  end

  # Turns a spline's u (e.g. 2.25) into the index of the segment it falls in and how far along
  # that segment it is: {2, 0.25}. A whole number u is the end of the previous segment
  # (t = 1.0), except u = 0. A small negative u (Spline.solve/3 allows down to -0.001) gives
  # segment 0 with a negative t, which extends the first segment slightly before the start.
  # u must be a float (Numbers.split_float/1 only takes floats); Spline.solve/3 converts it first.
  @spec split_u(float()) :: {non_neg_integer(), float()}
  def split_u(u), do: u |> Curves.Utils.Numbers.split_float() |> to_index()

  @spec to_index({integer(), float()}) :: {non_neg_integer(), float()}
  defp to_index({0, +0.0}), do: {0, 0.0}
  defp to_index({index, +0.0}), do: {index - 1, 1.0}
  defp to_index({index, t}), do: {index, t}
end
