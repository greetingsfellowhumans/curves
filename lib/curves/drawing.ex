defmodule Curves.Drawing do
  @moduledoc ~s"""
  A picture read from an SVG with `Curves.from_svg/2`: its shapes as curves, in the same groups and
  order, with everything else kept as markup, so `Curves.Svg` can draw it again as it was.

  ```elixir
  drawing = Curves.from_svg(File.read!("logo.svg"))

  # Every shape, wherever it is in the picture
  for shape <- Curves.Drawing.shapes(drawing), subpath <- shape.subpaths do
    Curves.solve!(subpath.curve, 0.5)
  end

  # Draw it again, as designed
  Curves.Svg.save!(drawing, "logo_again.svg")
  ```

  | Field | What it holds |
  | --- | --- |
  | `:width`, `:height` | the `<svg>` element's `width` and `height`, as written (they may have units), or `nil` |
  | `:view_box` | its `viewBox` as `{min_x, min_y, width, height}`, or `nil` |
  | `:attributes` | all of the `<svg>` element's own attributes, as strings |
  | `:children` | what is in it, in order: a `Curves.Drawing.Shape` for each shape, a `Curves.Drawing.Group` for each group, and a `Curves.Drawing.Raw` for everything else that is kept as markup, like text |
  | `:skipped` | everything that couldn't be read as curves, and why, so nothing goes missing silently |

  Each entry in `:skipped` is a map: `%{element: "text", id: "title", reason: :not_supported}`.
  The reasons are:

  | Reason | Meaning |
  | --- | --- |
  | `:not_supported` | an element that isn't made of curves (`<text>`, `<image>`, `<use>`, a nested `<svg>`). It is still kept as markup (a `Curves.Drawing.Raw`), so it is drawn again. `<script>` and `<foreignObject>` are the exception: they are never kept. |
  | `:empty` | a shape SVG doesn't draw, like a circle with radius `0` |
  | `{:invalid, message}` | a shape SVG treats as an error, like a negative radius |
  | `{:unsupported_unit, value}` | a size in `%`, `em`, `mm` and so on, which needs a screen to measure; only plain numbers and `px` are read. The shape is kept as markup, so it is drawn again. |
  | `{:invalid_transform, message}` | a `transform` that couldn't be read. The element (and, for a group, everything in it) isn't read as curves, but is kept as markup, so it is drawn again however a viewer draws it. |
  | `{:invalid_path, message}` | path data with an error in it. Like a browser, the shape still has the subpaths before the error. |
  """
  alias Curves.Drawing.{Group, Raw, Shape}

  defstruct width: nil,
            height: nil,
            view_box: nil,
            attributes: %{},
            children: [],
            skipped: []

  @typedoc "A transform, `{a, b, c, d, e, f}`, like SVG's `matrix(a, b, c, d, e, f)`."
  @type matrix() :: {float(), float(), float(), float(), float(), float()}

  @typedoc "Something inside a drawing or a group."
  @type child() :: Shape.t() | Group.t() | Raw.t()

  @typedoc "Something that couldn't be read as curves. See the table above."
  @type skipped() :: %{element: String.t(), id: String.t() | nil, reason: term()}

  @type t() :: %__MODULE__{
          width: String.t() | nil,
          height: String.t() | nil,
          view_box: {float(), float(), float(), float()} | nil,
          attributes: %{String.t() => String.t()},
          children: list(child()),
          skipped: list(skipped())
        }

  @doc ~s"""
  Every shape in the drawing, in order, including those inside groups.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle r="1"/><g><rect width="2" height="1"/></g></svg>))
      iex> drawing |> Curves.Drawing.shapes() |> Enum.map(& &1.element)
      [:circle, :rect]
  """
  @spec shapes(t() | Group.t()) :: list(Shape.t())
  def shapes(%{children: children}), do: Enum.flat_map(children, &child_shapes/1)

  @spec child_shapes(child()) :: list(Shape.t())
  defp child_shapes(%Shape{} = shape), do: [shape]
  defp child_shapes(%Group{} = group), do: shapes(group)
  defp child_shapes(%Raw{}), do: []

  @doc ~s"""
  Every curve in the drawing, shape by shape and subpath by subpath, in order.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle r="1"/><path d="M0 0 L1 1 M5 5 L6 6"/></svg>))
      iex> drawing |> Curves.Drawing.curves() |> length()
      3
  """
  @spec curves(t()) :: list(Curves.Spline.Curve.t() | Curves.Polyline.Curve.t())
  def curves(%__MODULE__{} = drawing),
    do: for(shape <- shapes(drawing), subpath <- shape.subpaths, do: subpath.curve)
end
