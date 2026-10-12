defmodule Curves.Drawing.Shape do
  @moduledoc ~s"""
  One shape from an SVG (see `Curves.Drawing`): which element it was, and its curves.

  | Field | What it holds |
  | --- | --- |
  | `:element` | `:path`, `:rect`, `:circle`, `:ellipse`, `:line`, `:polyline` or `:polygon` |
  | `:id` | its `id` attribute, or `nil` |
  | `:subpaths` | a `Curves.Drawing.Subpath` for each separate piece. Most shapes have one; a path has one per `M` (move), so a letter "O" has two: its outside and its hole. |
  | `:attributes` | all of the element's own attributes, as strings, e.g. `%{"fill" => "red"}`. Styles from CSS or from groups around it aren't included. |

  The curves are in the SVG's own coordinates, with every `transform` (on the shape and the groups
  around it) already applied, so they are where the shape is drawn.
  """
  alias Curves.Drawing.Subpath

  defstruct element: nil,
            id: nil,
            subpaths: [],
            attributes: %{}

  @type element() :: :path | :rect | :circle | :ellipse | :line | :polyline | :polygon

  @type t() :: %__MODULE__{
          element: element(),
          id: String.t() | nil,
          subpaths: list(Subpath.t()),
          attributes: %{String.t() => String.t()}
        }
end
