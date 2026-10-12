defmodule Curves.Drawing.Subpath do
  @moduledoc ~s"""
  One continuous piece of a shape (see `Curves.Drawing.Shape`): a curve, and whether it is closed.

  | Field | What it holds |
  | --- | --- |
  | `:curve` | a `Curves.Spline.Curve` (paths, rectangles, circles and ellipses) or a `Curves.Polyline.Curve` (lines, polylines and polygons). Use it with `Curves.solve/3`, `Curves.take/3`, `Curves.Transform` and `Curves.Svg` like any other curve. |
  | `:closed` | `true` when it joins back to its start: a path closed with `Z`, a polygon, a rectangle, a circle or an ellipse. The curve already includes the line back to the start. |
  """

  defstruct curve: nil,
            closed: false

  @type t() :: %__MODULE__{
          curve: Curves.Spline.Curve.t() | Curves.Polyline.Curve.t(),
          closed: boolean()
        }
end
