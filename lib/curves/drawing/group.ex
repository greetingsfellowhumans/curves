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
  | `:children` | what is inside it, in order: `Curves.Drawing.Shape`, `Curves.Drawing.Group` and `Curves.Drawing.Raw` |
  """

  defstruct element: "g",
            id: nil,
            attributes: %{},
            children: []

  @type t() :: %__MODULE__{
          element: String.t(),
          id: String.t() | nil,
          attributes: %{String.t() => String.t()},
          children: list(Curves.Drawing.child())
        }
end
