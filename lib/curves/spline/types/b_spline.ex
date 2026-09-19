defmodule Curves.Spline.Type.BSpline do
  @moduledoc false
  use Curves.Spline.Type,
    override_segment_parsing: true



  #@matrix ~MAT<
  #  1   4  1 0
  #  -3  0  3 0
  #  3  -6  3 0
  #  -1  3 -3 1
  #>
  @matrix ~MAT<
    1   0  0 0
    -3  3  0 0
    3  -6  3 0
    -1  3 -3 1
  >

  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix

  #@impl true
  #def power_series(t) do
  #  [1, t, t ** 2, t ** 3]
  #  |> Nx.tensor()
  #  #|> Nx.divide(6)
  #end

  #def map_segments(segments_list, curve) do
  #  dbg segments_list
  #  segments_list
  #end

  @impl true
  def define(points, opts \\ []) do
    points = rebuild_points(points, opts)
            |> auto_last([])
    points
      |> Curves.define_spline(:b_spline, opts)
  end
  def auto_last([[p0, p1, p2], [p3 | _] = next_segment | segments], acc) do
    acc = [ [p0, p1, p2, p3] | acc]
    segments = [next_segment | segments]
    auto_last(segments, acc)
  end
  def auto_last(_, acc), do: acc

  def rebuild_points(points, opts) do
    rebuild_points(points, opts, [])
  end
  def rebuild_points([p0, p1, p2 | all_points], opts, acc) do
    [_m0, m1] = split_points(p0, p1, 2)
    [m2, m3] = split_points(p1, p2, 2)
    [cp0] = split_points(m1, m2, 1)
    segment = [cp0, m2, m3]
    acc = [segment | acc]
    rebuild_points([p1, p2 | all_points], opts, acc)
  end
  def rebuild_points(_, _opts, acc), do: Enum.reverse(acc)

  
  def split_points(point_a, point_b, midpoints \\ 2) do
    {ax, ay} = point_a
    {my, mx} =  get_slope(point_a, point_b)
    xmid = mx / (midpoints + 1)
    ymid = my / (midpoints + 1)
    for i <- 1..midpoints do
      {ax + (i * xmid), ay + (i * ymid)}
    end
  end

  def get_slope({x0, y0}, {x1, y1}) do
    x = x1 - x0
    y = y1 - y0
    {y, x}
  end

  #@impl true
  #def map_segments(all_segments, _curve) do
  #  Enum.map(all_segments, fn {[ [x1, _, _, x2], [y1, _, _, y2] ] = segment, segment_idx} ->
  #    #{x0, y0} = get_prev_coord(all_segments, segment_idx, segment)
  #    #{x3, y3} = get_next_coord(all_segments, segment_idx, segment)

  #    #map_segment([ [x0, x1, x2, x3], [y0, y1, y2, y3] ])
  #    segment
  #  end)
  #end

  #def map_segment([[x0, x1, x2, x3], [y0, y1, y2, y3]]) do
  #[
  #    [x0, x1, x2, x3],
  #    [y0, y1, y2, y3]
  #]
  #end

  #def get_control_point({x1, y1}, left, right) do
  #  {my, mx} = get_slope(left, right)
  #  tension = 6
  #  {x1 + mx / tension, y1 + my / tension}
  #end

  #def get_prev_coord(all_segments, segment_idx, [ [x1, _, _, x2], [y1, _, _, y2] ]) do
  #  prev_idx = segment_idx - 1
  #  if prev_idx >= 0 do
  #    prev_seg = Enum.at(all_segments, segment_idx - 1)
  #    {[ [x0, _, _, _x1], [y0, _, _, _y1] ], _idx} = prev_seg
  #    {x0, y0}
  #  else
  #    x = x1 + (x1 - x2)
  #    y = y1 + (y1 - y2)
  #    {x, y}
  #  end
  #end
  #def get_next_coord(all_segments, segment_idx, [ [x1, _, _, x2], [y1, _, _, y2] ]) do
  #  next_seg = Enum.at(all_segments, segment_idx + 1)
  #  case next_seg do
  #    {[ [_, _, _, x3], [_, _, _, y3] ], _idx} -> {x3, y3}

  #    # Just mirror the slope from here to the next point
  #    nil ->
  #      x = x2 + (x2 - x1)
  #      y = y2 + (y2 - y1)
  #      {x, y}
  #  end
  #end


end
