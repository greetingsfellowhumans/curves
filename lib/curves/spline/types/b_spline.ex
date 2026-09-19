defmodule Curves.Spline.Type.BSpline do
  @moduledoc ~s"""
  Very smooth, but with the drawback that the line does not actually pass through the control points.

  ```elixir
  curve = Curves.define_b_spline([
      {0, -2},
      {3, 4},
      {6, 5},
      {7, -1},
      {10, 3},
      {5, 1},
      {12, 9}
  ])

  for i <- 0..1000 do
    Curves.solve!(curve, i / 1000)
  end
  |> # render_vega_lite_chart(...)
  ```

  ![B-Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/b_spline.png)
  """
  use Curves.Spline.Type,
    override_segment_parsing: true


  @matrix ~MAT<
    1   0  0 0
    -3  3  0 0
    3  -6  3 0
    -1  3 -3 1
  >

  @doc false
  @impl true
  def point_count(), do: 4

  @doc false
  @impl true
  def blending_function(), do: @matrix


  @doc false
  @impl true
  def define(points, opts \\ []) do
    points = rebuild_points(points, opts)
            |> auto_last([])
    points
      |> Curves.define_spline(:b_spline, opts)
  end


  defp auto_last([[p0, p1, p2], [p3 | _] = next_segment | segments], acc) do
    acc = [ [p0, p1, p2, p3] | acc]
    segments = [next_segment | segments]
    auto_last(segments, acc)
  end
  defp auto_last(_, acc), do: acc


  defp rebuild_points(points, opts) do
    rebuild_points(points, opts, [])
  end
  defp rebuild_points([p0, p1, p2 | all_points], opts, acc) do
    [_m0, m1] = split_points(p0, p1, 2)
    [m2, m3] = split_points(p1, p2, 2)
    [cp0] = split_points(m1, m2, 1)
    segment = [cp0, m2, m3]
    acc = [segment | acc]
    rebuild_points([p1, p2 | all_points], opts, acc)
  end
  defp rebuild_points(_, _opts, acc), do: Enum.reverse(acc)


  defp split_points(point_a, point_b, midpoints) do
    {ax, ay} = point_a
    {my, mx} =  get_slope(point_a, point_b)
    xmid = mx / (midpoints + 1)
    ymid = my / (midpoints + 1)
    for i <- 1..midpoints do
      {ax + (i * xmid), ay + (i * ymid)}
    end
  end


  defp get_slope({x0, y0}, {x1, y1}) do
    x = x1 - x0
    y = y1 - y0
    {y, x}
  end


end
