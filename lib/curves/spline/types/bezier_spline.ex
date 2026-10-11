defmodule Curves.Spline.Type.BezierSpline do
  @moduledoc ~s"""
  A chain of Bezier curves, each one starting where the last one ended.

  Each point is a list: a knot, then the control points of the curve from that knot to the next one,
  just like the commands in an SVG path (or `bezierCurveTo` on a canvas):

  | Point | Curve to the next knot | SVG |
  | --- | --- | --- |
  | `[knot]` | a straight line | `L` |
  | `[knot, c]` | a quadratic curve pulled towards `c` | `Q` |
  | `[knot, c0, c1]` | a cubic curve: leaves `knot` towards `c0`, arrives at the next knot from `c1` | `C` |

  The last point only ends the curve, so it must be `[knot]`.

  ```elixir
  points = [
    # Each point: a knot, then the control points of the curve to the next knot.
    [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],    # cubic to {10, 5}   (SVG C)
    [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}],    # cubic to {15, 10}
    [{15.0, 10.0}, {15.0, 14.0}, {18.0, 15.0}], # cubic to {20, 15}
    [{20.0, 15.0}, {23.0, 15.0}, {32.0, 5.0}],  # cubic to {30, 10}
    [{30.0, 10.0}]                              # the last knot only ends the curve
  ]
  curve = Curves.define_bezier_spline(points)

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "bezier_spline.svg")
  ```

  ![Bezier Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/bezier_spline.svg)

  """
  use Curves.Spline.Type

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  @doc false
  @impl true
  def define(points, opts \\ []) do
    Curves.define_spline(points, :bezier_spline, opts)
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Lines from each control point to the knot it pulls on, rather than one line through every point.
  @doc false
  @impl true
  def control_lines(points), do: Curves.Utils.Segment.control_lines(points)
end
