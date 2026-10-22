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
  | `[knot, {:arc, rx, ry, rotation, large_arc, sweep}]` | an elliptical arc | `A` |

  The last point only ends the curve, so it must be `[knot]`.

  ## Arcs

  An arc goes from its knot to the next knot along an ellipse with radii `rx` and `ry`, whose x axis
  is tilted by `rotation` degrees, exactly like SVG's `A rx ry rotation large-arc-flag sweep-flag x y`
  (with `true` and `false` for SVG's `1` and `0`). There are usually four such arcs between two
  points, and the flags pick one:

  * `large_arc` - `true` takes the long way round (more than half the ellipse), `false` the short way.
  * `sweep` - `true` makes the angle go up: anticlockwise in Curves' pictures, where y goes up, and
    clockwise on an SVG screen, where y goes down. `false` goes the other way.

  | | `sweep: false` | `sweep: true` |
  | --- | --- | --- |
  | `large_arc: false` | ![Short way, angle going down](images/arc_flags_false_false.svg) | ![Short way, angle going up](images/arc_flags_false_true.svg) |
  | `large_arc: true` | ![Long way, angle going down](images/arc_flags_true_false.svg) | ![Long way, angle going up](images/arc_flags_true_true.svg) |

  Also like SVG: radii too small to reach the next knot are scaled up until they just do, a radius of
  `0` draws a straight line, negative radii count as positive, and an arc to a knot in the same
  place draws nothing (the segment stays on that point). An arc is exact (it is not made of Bezier
  curves), starts and ends exactly on its knots, and moves through its angle at a steady rate.

  The curve stores some extra points for each arc, between its knots: the arc is cut into pieces of
  at most a quarter turn, and each piece adds the point where the tangents at its ends meet (and its
  end). The arc never goes outside them, so `:force_percent` stays within `0.0..1.0`, and
  `Curves.Svg` draws them as dots with dashed lines, like a quadratic curve's control point.

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
    points
    |> Curves.Utils.Errors.check_points!()
    |> Curves.define_spline(:bezier_spline, opts)
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Lines from each control point to the knot it pulls on, rather than one line through every point.
  @doc false
  @impl true
  def control_lines(points), do: Curves.Utils.Segment.control_lines(points)

  # Every knot and control point, plus the hull points of any arcs, so arcs stay inside them.
  @doc false
  @impl true
  def stored_points(points), do: Curves.Utils.Segment.stored_points(points)
end
