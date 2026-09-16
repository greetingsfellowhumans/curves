defmodule Curves.Spline.Type.BSpline do
  @moduledoc false
  use Curves.Spline.Type


  @matrix ~MAT<
    1   4  1 0
    -3  0  3 0
    3  -6  3 0
    -1  3 -3 1
  >

  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix

  @impl true
  def power_series(t) do
    [1, t, t ** 2, t ** 3]
    |> Nx.tensor()
    |> Nx.divide(6)
  end

  #def map_segments(segments_list, curve) do
  #  dbg segments_list
  #  segments_list
  #end

  @impl true
  def map_segments(all_segments, _curve) do
    Enum.map(all_segments, fn {[ [x1, _, _, x2], [y1, _, _, y2] ] = segment, segment_idx} ->
      {x0, y0} = get_prev_coord(all_segments, segment_idx, segment)
      {x3, y3} = get_next_coord(all_segments, segment_idx, segment)

      map_segment([ [x0, x1, x2, x3], [y0, y1, y2, y3] ])
    end)
  end

  def map_segment([[x0, x1, x2, x3], [y0, y1, y2, y3]]) do
  [
      [x0, x1, x2, x3],
      [y0, y1, y2, y3]
  ]
  end
  #def get_slope({inner_x, inner_y}, {outer_x, outer_y}) do
  #  x = outer_x - inner_x
  #  y = outer_y - inner_y
  #  {y, x}
  #end

  #def get_control_point({x1, y1}, left, right) do
  #  {my, mx} = get_slope(left, right)
  #  tension = 6
  #  {x1 + mx / tension, y1 + my / tension}
  #end

  def get_prev_coord(all_segments, segment_idx, [ [x1, _, _, x2], [y1, _, _, y2] ]) do
    prev_idx = segment_idx - 1
    if prev_idx >= 0 do
      prev_seg = Enum.at(all_segments, segment_idx - 1)
      {[ [x0, _, _, _x1], [y0, _, _, _y1] ], _idx} = prev_seg
      {x0, y0}
    else
      x = x1 + (x1 - x2)
      y = y1 + (y1 - y2)
      {x, y}
    end
  end
  def get_next_coord(all_segments, segment_idx, [ [x1, _, _, x2], [y1, _, _, y2] ]) do
    next_seg = Enum.at(all_segments, segment_idx + 1)
    case next_seg do
      {[ [_, _, _, x3], [_, _, _, y3] ], _idx} -> {x3, y3}

      # Just mirror the slope from here to the next point
      nil ->
        x = x2 + (x2 - x1)
        y = y2 + (y2 - y1)
        {x, y}
    end
  end


end
