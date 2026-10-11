defmodule Curves.Utils.Segment do
  @moduledoc false
  # A segment is a tensor of shape {2, 4} holding two knots and two control points.
  # This is the format that can easily be passed into a matrix formula to solve a curve.
  # such that [knot0, cp0, cp1, knot1]
  alias Curves.Utils.TensorTypes, as: TensorT
  alias Curves.Utils.Types, as: T
  @type map_format() :: %{knot: T.point_tuple(), c0: T.point_tuple(), c1: T.point_tuple()}
  # Any length
  @type loose_list() :: list(T.point_tuple())
  # Lenght == 4
  @type tight_list() :: list(T.point_tuple())

  alias Curves.Utils.Points

  # Builds cubic segments from a bezier spline's points, each given as [knot], [knot, c] or [knot, c0, c1].
  @spec new_segments(list(list(T.point_tuple())), T.opts()) :: TensorT.cubic_segments()
  def new_segments(lists, opts \\ []) do
    lists
    |> Enum.map(&to_map_format(&1))
    |> normalize_length()
    |> Enum.reverse()
    |> Enum.map(&Points.new_points(&1, opts))
    |> Nx.stack(name: :segment)
  end

  # Turns each pair of neighbouring points into a 4-point segment, [knot, c1, next c0, next knot].
  # The result is built back to front, so new_segments/2 reverses it.
  @spec normalize_length(list(map_format())) :: list(tight_list())
  defp normalize_length(coords) do
    coords
    |> normalize_length([])
  end

  @spec normalize_length(list(map_format()), list(tight_list())) :: list(tight_list())
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

  # Turns a spline's u (e.g. 2.25) into the segment it falls in and how far along it is: {segment 2, t 0.25}.
  # A whole number u is the end of the previous segment (t = 1.0), except u = 0.
  # A small negative u (Spline.solve/3 allows down to -0.001) gives segment 0 with a negative t,
  # which extends the first segment slightly before the start.
  # u must be a float (Numbers.split_float/1 only takes floats); Spline.solve/3 converts it first.
  @spec split_u(Curves.Spline.Curve.t() | TensorT.cubic_segments(), float()) ::
          {TensorT.cubic_segment(), float()}
  def split_u(%{segments: segments}, u), do: split_u(segments, u)

  def split_u(segments, u) do
    {segment_idx, t} = Curves.Utils.Numbers.split_float(u)

    case {segment_idx, t} do
      # absolute 0%. Works as normal.
      {0, +0.0} -> {segments[segment_idx], 0.0}
      # at 1.0, we actually want segment: 0, and t: 1.0. NOT seg: 1, t: 0.0
      {_, +0.0} -> {segments[segment_idx - 1], 1.0}
      # Everything else works as normal
      {_, _t} -> {segments[segment_idx], t}
    end
  end

  @spec get_knot0(TensorT.cubic_segment()) :: TensorT.point()
  def get_knot0(segment) do
    Nx.slice(segment, [0, 0], [2, 1])
  end

  @spec get_knot1(TensorT.cubic_segment()) :: TensorT.point()
  def get_knot1(segment) do
    Nx.slice(segment, [0, 3], [2, 1])
  end
end
