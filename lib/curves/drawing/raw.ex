defmodule Curves.Drawing.Raw do
  @moduledoc ~s"""
  Part of an SVG that isn't made of curves, such as `<text>`, `<image>`, `<defs>` or `<style>`,
  kept as its markup so that drawing the `Curves.Drawing` again includes it.

  | Field | What it holds |
  | --- | --- |
  | `:element` | its element's name, e.g. `"text"` |
  | `:markup` | its SVG markup. It is the original, made safe and well formed: `<script>` and `<foreignObject>` elements, animations of links and event handlers, event attributes (`onclick` and so on), `javascript:` links and invalid names are taken out, tags left open are closed, and stray or unfinished tags are left out. |
  | `:transform` | the transforms of the groups around it, as `{a, b, c, d, e, f}` (like SVG's `matrix(a, b, c, d, e, f)`), since those groups are drawn without them. Its own `transform` is still in its markup. |
  """

  defstruct element: nil,
            markup: "",
            transform: {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  @type t() :: %__MODULE__{
          element: String.t(),
          markup: String.t(),
          transform: Curves.Drawing.matrix()
        }
end
