defmodule Curves.Utils.Segment do
  @moduledoc false
  # A segment is a tensor of shape {2, 4} holding two knots and two control points. 
  # This is the format that can easily be passed into a matrix formula to solve a curve.
  # such that [knot0, cp0, cp1, knot1]
  alias Curves.Utils.Types, as: T
  @type map_format() :: %{knot: T.point_tuple(), c0: T.point_tuple(), c1: T.point_tuple()}
  @type loose_list() :: list(T.point_tuple()) # Any length
  @type tight_list() :: list(T.point_tuple()) # Lenght == 4

  alias Curves.Utils.{Points}

  defguard is_segment(p)
           when is_struct(p, Nx.Tensor) and elem(p.shape, 0) == 2 and elem(p.shape, 1) == 4

  def new_segments(lists, opts \\ []) do
    lists
      |> Enum.map(&to_map_format(&1))
      |> normalize_length()
      |> Enum.reverse()
      |> Enum.map(&Points.new_points(&1, opts))
      |> Nx.stack(name: :segment)
  end


  defp normalize_length(coords) do
    coords
      |> normalize_length([])
  end
  defp normalize_length([hd], acc) do
    [[ hd.c0, hd.knot, hd.knot, hd.c1 ] | acc]
  end
  defp normalize_length([hd, next], acc) do
    [[ hd.knot, hd.c1, next.c0, next.knot ] | acc]
  end
  defp normalize_length([hd, next | tl], acc) do
    acc = [[ hd.knot, hd.c1, next.c0, next.knot ] | acc]
    normalize_length([next | tl], acc)
  end

  defp to_map_format([knot]), do: %{knot: knot, c0: knot, c1: knot}
  defp to_map_format([knot, c]), do: %{knot: knot, c0: c, c1: c}
  defp to_map_format([knot, c0, c1]), do: %{knot: knot, c0: c0, c1: c1}


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

  def get_knot0(segment) do
    Nx.slice(segment, [0, 0], [2, 1])
  end
  def get_control_point0(segment) do
    Nx.slice(segment, [0, 1], [2, 1])
  end
  def get_control_point1(segment) do
    Nx.slice(segment, [0, 2], [2, 1])
  end
  def get_knot1(segment) do
    Nx.slice(segment, [0, 3], [2, 1])
  end
end
