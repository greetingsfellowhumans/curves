defmodule Curves.Drawing.Shape do
  @moduledoc ~s"""
  One shape from an SVG (see `Curves.Drawing`): which element it was, and its curves.

  | Field | What it holds |
  | --- | --- |
  | `:element` | `:path`, `:rect`, `:circle`, `:ellipse`, `:line`, `:polyline` or `:polygon` |
  | `:id` | its `id` attribute, or `nil` |
  | `:subpaths` | a `Curves.Drawing.Subpath` for each separate piece. Most shapes have one; a path has one per `M` (move), so a letter "O" has two: its outside and its hole. |
  | `:attributes` | all of the element's own attributes, as strings, e.g. `%{"fill" => "red"}`. Styles from CSS or from groups around it aren't included. |
  | `:transform` | every SVG `transform` that applied to it (its own and its groups'), as one matrix `{a, b, c, d, e, f}` (like SVG's `matrix(a, b, c, d, e, f)`) |
  | `:origin`, `:scale`, `:rotation` | how `Curves.Transform` has moved, scaled and rotated the whole shape since it was read. They start at `{0.0, 0.0}`, `1.0` and `0.0`. |

  The curves are in the SVG's own coordinates, with `:transform` already applied, so they are where
  the shape is drawn. `Curves.Svg` uses `:transform` to draw the shape the way the SVG did: a stroke
  inside a `scale(2)` group is twice as wide.
  """
  alias Curves.Drawing.Subpath

  defstruct element: nil,
            id: nil,
            subpaths: [],
            attributes: %{},
            transform: {1.0, 0.0, 0.0, 1.0, 0.0, 0.0},
            origin: {0.0, 0.0},
            scale: 1.0,
            rotation: 0.0

  @type element() :: :path | :rect | :circle | :ellipse | :line | :polyline | :polygon

  @type t() :: %__MODULE__{
          element: element(),
          id: String.t() | nil,
          subpaths: list(Subpath.t()),
          attributes: %{String.t() => String.t()},
          transform: Curves.Drawing.matrix(),
          origin: Curves.Types.point_tuple(),
          scale: number() | {number(), number()},
          rotation: float()
        }
end
