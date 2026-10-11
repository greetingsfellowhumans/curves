defmodule Curves.Utils.Segment do
  @moduledoc false
  # A segment is a list of 4 points, [knot0, cp0, cp1, knot1]: the shape every spline type is
  # solved in. Each spline type decides what the 4 points mean (e.g. Catmull-Rom uses
  # [previous knot, knot0, knot1, next knot]); its blending matrix turns them into a curve.
  alias Curves.Types, as: T
  alias Curves.Utils.Vec

  @type map_format() :: %{knot: T.point_tuple(), c0: T.point_tuple(), c1: T.point_tuple()}
  # Exactly 4 points.
  @type t() :: list(T.point_tuple())

  # Builds cubic segments from a bezier spline's points, each given as [knot], [knot, c] or [knot, c0, c1].
  # Coordinates are turned into floats.
  @spec new_segments(list(list(T.point_tuple()))) :: list(t())
  def new_segments(lists) do
    lists
    |> Enum.map(&to_map_format(&1))
    |> normalize_length()
    |> Enum.reverse()
    |> Enum.map(fn segment -> Enum.map(segment, &Vec.new/1) end)
  end

  # Turns each pair of neighbouring points into a 4-point segment, [knot, c1, next c0, next knot].
  # The result is built back to front, so new_segments/1 reverses it.
  @spec normalize_length(list(map_format())) :: list(t())
  defp normalize_length(coords) do
    coords
    |> normalize_length([])
  end

  @spec normalize_length(list(map_format()), list(t())) :: list(t())
  defp normalize_length([hd], acc) do
    [[hd.c0, hd.knot, hd.knot, hd.c1] | acc]
  end

  defp normalize_length([hd, next], acc) do
    [[hd.knot, hd.c1, next.c0, next.knot] | acc]
  end

  defp normalize_length([hd, next | tl], acc) do
    acc = [[hd.knot, hd.c1, next.c0, next.knot] | acc]
    normalize_length([next | tl], acc)
  end

  # A missing control point defaults to the one given, or to the knot itself.
  @spec to_map_format(term()) :: map_format()
  defp to_map_format([knot]), do: %{knot: knot, c0: knot, c1: knot}
  defp to_map_format([knot, c]), do: %{knot: knot, c0: c, c1: c}
  defp to_map_format([knot, c0, c1]), do: %{knot: knot, c0: c0, c1: c1}

  # Anything else is a malformed input to define_bezier_spline/2, e.g. a plain {x, y} instead of [{x, y}].
  defp to_map_format(other) do
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
