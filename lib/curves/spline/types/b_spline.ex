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

  # Find any point along the curve (u goes from 0.0 to curve.max_u)...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "b_spline.svg")
  ```

  ![B-Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/b_spline.svg)

  ## How it is built

  The B-spline is turned into a chain of cubic Bezier segments, one for every 3 points in a row,
  and those are solved like a Bezier spline. Each segment starts at `(p0 + 4 * p1 + p2) / 6`,
  which is where a B-spline crosses between segments. So `n` points give `n - 3` segments,
  and `max_u` is `n - 3`.

  ## Stored points

  `curve.points` holds those generated Bezier points, not the points you passed in:
  4 per segment, with each joint stored twice. For example, 6 points become 12.
  This also affects:

  * `:xmin`, `:xmax`, `:ymin` and `:ymax`, which are measured from the generated points.
  * `:force_percent`, which rescales between those bounds instead of between your points.
  * `Curves.Svg`, which draws the generated points as its dots.
  """
  use Curves.Spline.Type,
    override_segment_parsing: true

  alias Curves.Types, as: T

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
    points =
      rebuild_points(points, opts)
      |> auto_last([])

    points
    |> Curves.define_spline(:b_spline, opts)
  end

  # Completes each [cp0, m2, m3] with the next segment's cp0, so every segment has 4 points.
  @spec auto_last(list(T.point_list()), list(T.point_list())) :: list(T.point_list())
  defp auto_last([[p0, p1, p2], [p3 | _] = next_segment | segments], acc) do
    acc = [[p0, p1, p2, p3] | acc]
    segments = [next_segment | segments]
    auto_last(segments, acc)
  end

  # acc is built back to front, so flip it to keep the segments in curve order.
  defp auto_last(_, acc), do: Enum.reverse(acc)

  # One [cp0, m2, m3] Bezier start per 3 points in a row; see "How it is built" above.
  @doc false
  @spec rebuild_points(T.point_list(), T.opts()) :: list(T.point_list())
  def rebuild_points(points, opts) do
    rebuild_points(points, opts, [])
  end

  @doc false
  @spec rebuild_points(T.point_list(), T.opts(), list(T.point_list())) :: list(T.point_list())
  def rebuild_points([p0, p1, p2 | all_points], opts, acc) do
    [_m0, m1] = split_points(p0, p1, 2)
    [m2, m3] = split_points(p1, p2, 2)
    [cp0] = split_points(m1, m2, 1)
    segment = [cp0, m2, m3]
    acc = [segment | acc]
    rebuild_points([p1, p2 | all_points], opts, acc)
  end

  def rebuild_points(_, _opts, acc), do: Enum.reverse(acc)

  # `midpoints` evenly spaced points between point_a and point_b, e.g. 2 gives the 1/3 and 2/3 points.
  @doc false
  @spec split_points(T.point_tuple(), T.point_tuple(), pos_integer()) :: T.point_list()
  def split_points(point_a, point_b, midpoints) do
    {ax, ay} = point_a
    {my, mx} = get_slope(point_a, point_b)
    xmid = mx / (midpoints + 1)
    ymid = my / (midpoints + 1)

    for i <- 1..midpoints do
      {ax + i * xmid, ay + i * ymid}
    end
  end

  # {rise, run} from point_a to point_b.
  @spec get_slope(T.point_tuple(), T.point_tuple()) :: {number(), number()}
  defp get_slope({x0, y0}, {x1, y1}) do
    x = x1 - x0
    y = y1 - y0
    {y, x}
  end
end
