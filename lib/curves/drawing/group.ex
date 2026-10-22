defmodule Curves.Drawing.Group do
  @moduledoc ~s"""
  A group of shapes from an SVG's `<g>` (or `<a>` or `<switch>`), kept so that drawing the
  `Curves.Drawing` again looks the same: a group's `opacity`, `filter` or `clip-path` applies to
  everything in it together.

  | Field | What it holds |
  | --- | --- |
  | `:element` | `"g"`, `"a"` or `"switch"` |
  | `:id` | its `id` attribute, or `nil` |
  | `:attributes` | its own attributes, as strings, except `transform`: that is already applied to the shapes inside, and kept on each of them (see `Curves.Drawing.Shape`) |
  | `:transform` | every SVG `transform` that applied to it (its own and its groups'), as one matrix `{a, b, c, d, e, f}`, like a shape's. `Curves.Svg` draws the group with it, so its `clip-path`, `mask` or `filter` lines up with the shapes inside as it did. A group made by hand can leave it as it is: it never changes where the shapes are drawn. |
  | `:children` | what is inside it, in order: `Curves.Drawing.Shape`, `Curves.Drawing.Group` and `Curves.Drawing.Raw` |
  | `:origin`, `:scale`, `:rotation` | how `Curves.Transform` has moved, scaled and rotated the whole group (everything in it, text too). They start at `{0.0, 0.0}`, `1.0` and `0.0`. |
  """

  defstruct element: "g",
            id: nil,
            attributes: %{},
            transform: {1.0, 0.0, 0.0, 1.0, 0.0, 0.0},
            children: [],
            origin: {0.0, 0.0},
            scale: 1.0,
            rotation: 0.0

  @type t() :: %__MODULE__{
          element: String.t(),
          id: String.t() | nil,
          attributes: %{String.t() => String.t()},
          transform: Curves.Drawing.matrix(),
          children: list(Curves.Drawing.child()),
          origin: Curves.Types.point_tuple(),
          scale: number() | {number(), number()},
          rotation: float()
        }
end
