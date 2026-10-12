# Times reading SVGs (path data on its own, a small document with every kind of shape and some
# transforms, and the same document 100 times over), and writing them again.
Code.require_file("support/bench_helper.exs", __DIR__)
alias Curves.Bench.Helper

heart = "M 10,30 A 20,20 0,0,1 50,30 A 20,20 0,0,1 90,30 Q 90,60 50,90 Q 10,60 10,30 z"
long_path = "M0 0" <> String.duplicate(" L1 1 A2 2 0 0 1 3 3 C1 1 2 2 3 3", 1000)

shapes = """
<rect x="10" y="10" width="80" height="50" rx="12"/>
<circle cx="200" cy="40" r="25"/>
<ellipse cx="260" cy="40" rx="30" ry="15" transform="rotate(30 260 40)"/>
<g transform="translate(20 100) scale(1.5)"><g transform="skewX(20)">
  <path d="#{heart}"/>
</g></g>
<polygon points="150,100 180,160 120,160"/>
<polyline points="200 100 220 140 240 100 260 140"/>
<line x1="200" y1="180" x2="290" y2="170"/>
"""

document = "<svg viewBox=\"0 0 300 200\">" <> shapes <> "</svg>"
big_document = "<svg>" <> String.duplicate(shapes, 100) <> "</svg>"
drawing = Curves.from_svg(document)
[%{curve: long_curve}] = Curves.from_svg_path(long_path)

Helper.run("svg_import", %{
  "from_svg_path heart" => fn -> Curves.from_svg_path(heart) end,
  "from_svg_path 3000 segments" => fn -> Curves.from_svg_path(long_path) end,
  "from_svg 7 shapes" => fn -> Curves.from_svg(document) end,
  "from_svg 700 shapes" => fn -> Curves.from_svg(big_document) end,
  "Svg.render 7 shapes, as designed" => fn -> Curves.Svg.render(drawing) end,
  "Svg.path_data 3000 segments" => fn -> Curves.Svg.path_data(long_curve) end
})
