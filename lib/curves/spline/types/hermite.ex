defmodule Curves.Spline.Type.Hermite do
  @moduledoc ~s"""
  Hermite splines accept no control points. Only knots.
  Control points are calculated automatically based on the first derivative of each knot.

  Points: `[P0, P'0, P1, P'1]`
  """
  use Curves.Spline.Type,
    derivatives: [0, {:derivative, :p0, 1}, {:point, 1}, {:derivative, :p1, 1}],
    derivative: 0

  @matrix_new ~MAT<
    1 0 0 0
    0 1 0 0
    -3 -2 3 -1
    2 1 -2 1
  >

  def define_hermite(points, opts \\ []) do
    points = Enum.map(points, fn p -> [p] end)
    points
      |> Curves.define_spline(:hermite, opts)
  end

  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix_new

  # Points: [P0, P'0, P1, P'1]
  @impl true
  def map_segments(all_segments, curve) do
    Enum.map(all_segments, fn {segment_list, segment_idx} ->
      map_segment(curve, segment_list, segment_idx)
    end)
  end

  def map_segment(curve, [[x0, _x1, _x2, x3], [y0, _y1, _y2, y3]], idx) do
    u = idx * 1.0
    {dx, dy} = d(curve, u)
    {dx1, dy1} = d(curve, u + 1.0)

    [
      [x0, x0 + dx / 3, x3 - dx1 / 3, x3],
      [y0, y0 + dy / 3, y3 - dy1 / 3, y3]
    ]
  end

end
