defmodule Curves.Drawing do
  @moduledoc ~s"""
  A picture read from an SVG with `Curves.from_svg/2`: its shapes, each one as curves.

  ```elixir
  drawing = Curves.from_svg(File.read!("logo.svg"))

  for shape <- drawing.shapes, subpath <- shape.subpaths do
    Curves.solve!(subpath.curve, 0.5)
  end
  ```

  | Field | What it holds |
  | --- | --- |
  | `:width`, `:height` | the `<svg>` element's `width` and `height`, as written (they may have units), or `nil` |
  | `:view_box` | its `viewBox` as `{min_x, min_y, width, height}`, or `nil` |
  | `:shapes` | a `Curves.Drawing.Shape` for each shape that was read, in the order they appear |
  | `:skipped` | everything that couldn't be read as curves, and why, so nothing goes missing silently |

  Each entry in `:skipped` is a map: `%{element: "text", id: "title", reason: :not_supported}`.
  The reasons are:

  | Reason | Meaning |
  | --- | --- |
  | `:not_supported` | an element that isn't made of curves (`<text>`, `<image>`, `<foreignObject>`), or that Curves can't follow (`<use>`, a nested `<svg>`) |
  | `:empty` | a shape SVG doesn't draw, like a circle with radius `0` |
  | `{:invalid, message}` | a shape SVG treats as an error, like a negative radius |
  | `{:unsupported_unit, value}` | a size in `%`, `em`, `mm` and so on, which needs a screen to measure; only plain numbers and `px` are read |
  | `{:invalid_transform, message}` | a `transform` that couldn't be read; the element (and, for a group, everything in it) is skipped |
  | `{:invalid_path, message}` | path data with an error in it. Like a browser, the shape still has the subpaths before the error. |
  """
  alias Curves.Drawing.Shape

  defstruct width: nil,
            height: nil,
            view_box: nil,
            shapes: [],
            skipped: []

  @typedoc "Something that couldn't be read as curves. See the table above."
  @type skipped() :: %{element: String.t(), id: String.t() | nil, reason: term()}

  @type t() :: %__MODULE__{
          width: String.t() | nil,
          height: String.t() | nil,
          view_box: {float(), float(), float(), float()} | nil,
          shapes: list(Shape.t()),
          skipped: list(skipped())
        }

  @doc ~s"""
  Every curve in the drawing, shape by shape and subpath by subpath, in order.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle r="1"/><path d="M0 0 L1 1 M5 5 L6 6"/></svg>))
      iex> drawing |> Curves.Drawing.curves() |> length()
      3
  """
  @spec curves(t()) :: list(Curves.Spline.Curve.t() | Curves.Polyline.Curve.t())
  def curves(%__MODULE__{shapes: shapes}),
    do: for(shape <- shapes, subpath <- shape.subpaths, do: subpath.curve)
end
