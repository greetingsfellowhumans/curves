defmodule Curves.Svg.ImportPropertiesTest do
  # Properties of reading SVGs, checked on random input.
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Drawing

  @fragments [
    "<svg>",
    "</svg>",
    "<svg:svg>",
    "<g transform=\"",
    "scale(2)",
    "rotate(30 1 1)",
    "skewX(10)",
    "\">",
    "</g>",
    "<path d=\"",
    "M0 0",
    "L",
    "1",
    "-2.5",
    ".5e1",
    " ",
    ",",
    "A3 3 0 1 0",
    "Q",
    "T",
    "S",
    "z",
    "<circle r=\"5\"",
    "<rect width=\"4\" height=\"2\" rx=\"1\"",
    "<polygon points=\"",
    "<line x2=\"3\"",
    "<!--",
    "-->",
    "<![CDATA[",
    "]]>",
    "<?xml",
    "?>",
    "<!DOCTYPE [",
    "]>",
    "'",
    "\"",
    "<",
    ">",
    "/>",
    "&amp;",
    "&#9999999;",
    "&#x41;",
    "<defs>",
    "</defs>",
    "<text>",
    "</text>",
    "%",
    "px",
    "1e999"
  ]

  # Text that looks a bit like SVG, often broken.
  @spec svg_soup() :: StreamData.t(String.t())
  defp svg_soup do
    StreamData.map(
      StreamData.list_of(StreamData.member_of(@fragments), max_length: 40),
      &Enum.join/1
    )
  end

  @unsafe_fragments [
    "<script>",
    "</script>",
    " onclick=\"x\"",
    " ONLOAD='x'",
    " href=\"javascript:a\"",
    " href=\" jav&#x09;ascript:a\"",
    " xlink:href='vbscript:x'",
    "<foreignObject>",
    "</foreignObject>",
    "<set attributeName=\"href\" to=\"javascript:a\"/>",
    "<animate attributeName=\"onclick\"/>",
    "<a",
    "<text>",
    "</text>",
    "<style>",
    "</style>",
    "<defs>",
    "</defs>",
    "<g>",
    "</g>",
    "<x\"y>"
  ]

  # Every tag in some SVG is safe (no scripts, event handlers or javascript: links), and the tags
  # are properly closed and nested.
  @spec assert_safe_and_well_formed(String.t()) :: :ok
  defp assert_safe_and_well_formed(svg) do
    open =
      Enum.reduce(Curves.Svg.Import.tags(svg), [], fn
        {:open, name, attributes, self_closing}, open ->
          refute name in ["script", "foreignObject"], "#{name} in #{svg}"

          for {key, value} <- attributes do
            link = value |> String.replace(~r/[\x00-\x20\x7f]+/, "") |> String.downcase()
            refute String.starts_with?(String.downcase(key), "on"), "#{key} in #{svg}"
            refute String.starts_with?(link, ["javascript:", "vbscript:"]), "#{value} in #{svg}"
          end

          if self_closing, do: open, else: [name | open]

        {:close, name}, [name | open] ->
          open

        {:close, name}, open ->
          flunk("</#{name}> doesn't close #{inspect(open)} in #{svg}")
      end)

    assert open == []
    :ok
  end

  property "a drawing drawn again never has scripts in it, and is well formed" do
    check all(
            parts <-
              StreamData.list_of(StreamData.member_of(@unsafe_fragments ++ @fragments),
                max_length: 40
              )
          ) do
      drawing = Curves.from_svg("<svg>" <> Enum.join(parts) <> "</svg>")
      assert_safe_and_well_formed(Curves.Svg.render(drawing))
    end
  end

  property "any text gives a drawing, or an ArgumentError, and never crashes" do
    check all(
            text <-
              StreamData.one_of([svg_soup(), StreamData.binary(), StreamData.string(:printable)])
          ) do
      try do
        assert %Drawing{} = drawing = Curves.from_svg(text)
        # Every curve can be solved, and the drawing drawn
        for curve <- Drawing.curves(drawing), do: Curves.solve!(curve, Curves.max_u(curve) / 2)
        assert "<svg" <> _ = Curves.Svg.render(drawing, samples: 5)
      rescue
        error in ArgumentError -> assert error.message =~ ~r/no <svg> element/
      end
    end
  end

  # Pieces of path data, valid and not.
  @path_pieces ~w(M m L l H h V v C c S s Q q T t A a Z z 0 1 -3 .5 e2) ++ [" ", ","]

  property "any path data gives subpaths, or an ArgumentError" do
    check all(
            data <-
              StreamData.map(
                StreamData.list_of(StreamData.member_of(@path_pieces), max_length: 30),
                &Enum.join/1
              )
          ) do
      try do
        for subpath <- Curves.from_svg_path(data), do: Curves.solve!(subpath.curve, 0.5)
      rescue
        error in ArgumentError -> assert error.message =~ ~r/invalid path data/
      end
    end
  end

  # One drawing command (no M or Z), its arguments, and whether it is written relative.
  @spec command() :: StreamData.t({String.t(), list(), boolean()})
  defp command do
    n = StreamData.float(min: -50.0, max: 50.0)
    flag = StreamData.member_of([0, 1])
    r = StreamData.float(min: 0.5, max: 30.0)

    StreamData.bind(StreamData.member_of(~w(L H V C S Q T A)), fn letter ->
      args =
        case letter do
          "L" -> StreamData.fixed_list([n, n])
          "H" -> StreamData.fixed_list([n])
          "V" -> StreamData.fixed_list([n])
          "C" -> StreamData.fixed_list([n, n, n, n, n, n])
          "S" -> StreamData.fixed_list([n, n, n, n])
          "Q" -> StreamData.fixed_list([n, n, n, n])
          "T" -> StreamData.fixed_list([n, n])
          "A" -> StreamData.fixed_list([r, r, n, flag, flag, n, n])
        end

      StreamData.tuple({StreamData.constant(letter), args, StreamData.boolean()})
    end)
  end

  # Where a command ends, from the current point (the model the parser should match).
  @spec end_point({String.t(), list(), boolean()}, {float(), float()}) :: {float(), float()}
  defp end_point({"H", [x], relative}, {cx, cy}), do: {if(relative, do: cx + x, else: x), cy}
  defp end_point({"V", [y], relative}, {cx, cy}), do: {cx, if(relative, do: cy + y, else: y)}

  defp end_point({_letter, args, relative}, {cx, cy}) do
    [x, y] = Enum.take(args, -2)
    if relative, do: {cx + x, cy + y}, else: {x, y}
  end

  property "random path data, written any valid way, goes through the knots it should" do
    check all(
            start <-
              StreamData.tuple(
                {StreamData.float(min: -50.0, max: 50.0), StreamData.float(min: -50.0, max: 50.0)}
              ),
            commands <- StreamData.list_of(command(), min_length: 1, max_length: 8),
            separator <- StreamData.member_of([" ", ",", " , ", "\n", "  "])
          ) do
      {sx, sy} = start

      data =
        Enum.map_join(commands, " ", fn {letter, args, relative} ->
          letter = if relative, do: String.downcase(letter), else: letter
          letter <> Enum.map_join(args, separator, &to_string/1)
        end)

      [subpath] = Curves.from_svg_path("M#{sx}#{separator}#{sy} " <> data)

      {knots, _} =
        Enum.map_reduce(commands, start, fn command, current ->
          {end_point(command, current), end_point(command, current)}
        end)

      [start | knots]
      |> Enum.with_index()
      |> Enum.each(fn {{x, y}, i} ->
        {ax, ay} = Curves.solve!(subpath.curve, i * 1.0)
        assert abs(ax - x) <= 1.0e-6 and abs(ay - y) <= 1.0e-6
      end)
    end
  end

  property "a transform moves every point of a shape exactly, even a skew" do
    check all(
            matrix <- StreamData.list_of(StreamData.float(min: -3.0, max: 3.0), length: 6),
            shape <-
              StreamData.member_of([
                ~s|<path d="M0 0 L10 0 A5 3 30 0 1 10 10 Q5 15 0 10 z"/>|,
                ~s|<circle cx="2" cy="1" r="4"/>|,
                ~s|<ellipse rx="5" ry="2"/>|,
                ~s|<rect x="1" y="1" width="6" height="4" rx="1.5"/>|,
                ~s|<polygon points="0,0 4,1 2,5"/>|
              ]),
            f <- StreamData.float(min: 0.0, max: 1.0)
          ) do
      [a, b, c, d, e, g] = matrix
      plain = Curves.from_svg("<svg>" <> shape <> "</svg>") |> Drawing.curves() |> hd()

      moved =
        Curves.from_svg(
          ~s|<svg><g transform="matrix(#{Enum.join(matrix, " ")})">| <> shape <> "</g></svg>"
        )
        |> Drawing.curves()
        |> hd()

      u = f * Curves.max_u(plain)
      {x, y} = Curves.solve!(plain, u)
      {mx, my} = Curves.solve!(moved, u)
      assert abs(mx - (a * x + c * y + e)) <= 1.0e-9 * 100
      assert abs(my - (b * x + d * y + g)) <= 1.0e-9 * 100
    end
  end

  # The furthest any point of `a` is from the curve `b` (both sampled), to compare shapes whose `u`
  # differs (e.g. a circle written as several arcs).
  @spec furthest(Curves.Types.curve_struct(), Curves.Types.curve_struct()) :: float()
  defp furthest(a, b) do
    dense = [Curves.solve!(b, 0.0) | Curves.take!(b, 1500)]

    for i <- 0..40, reduce: 0.0 do
      acc ->
        {x, y} = Curves.solve!(a, i / 40 * Curves.max_u(a))

        nearest =
          dense |> Enum.map(fn {bx, by} -> (bx - x) ** 2 + (by - y) ** 2 end) |> Enum.min()

        max(acc, :math.sqrt(nearest))
    end
  end

  property "drawing a drawing and reading it back gives the same shapes, transforms and styles" do
    shapes = [
      ~s|<path d="M0 0 L10 0 A5 3 30 0 1 10 10 Q5 15 0 10 z M2 2 h3 v3 z" fill="red"/>|,
      ~s|<circle cx="2" cy="1" r="4" stroke="blue"/>|,
      ~s|<ellipse rx="5" ry="2" opacity="0.5"/>|,
      ~s|<rect x="1" y="1" width="6" height="4" rx="1.5" class="c"/>|,
      ~s|<polygon points="0,0 4,1 2,5"/>|,
      ~s|<line x2="3" y2="4" stroke-width="2"/>|
    ]

    check all(
            picked <-
              StreamData.list_of(StreamData.member_of(shapes), min_length: 1, max_length: 4),
            transforms <-
              StreamData.list_of(
                StreamData.member_of([
                  "",
                  "translate(3 -2)",
                  "scale(2 0.5)",
                  "rotate(30 1 1)",
                  "skewX(20)",
                  "matrix(1 0.5 -0.3 1.2 4 5)"
                ]),
                length: 4
              )
          ) do
      body =
        picked
        |> Enum.zip(transforms)
        |> Enum.map_join(fn {shape, transform} ->
          ~s|<g transform="#{transform}" opacity="0.9">#{shape}</g>|
        end)

      original = Curves.from_svg("<svg>" <> body <> "</svg>")
      again = original |> Curves.Svg.render() |> Curves.from_svg()

      for {a, b} <- Enum.zip(Drawing.shapes(original), Drawing.shapes(again)) do
        assert a.transform == b.transform

        assert Map.drop(
                 a.attributes,
                 ~w(d points x y width height rx ry cx cy r x1 y1 x2 y2 transform)
               ) ==
                 Map.drop(b.attributes, ["d", "transform"])

        assert Enum.map(a.subpaths, & &1.closed) == Enum.map(b.subpaths, & &1.closed)

        for {sa, sb} <- Enum.zip(a.subpaths, b.subpaths) do
          assert furthest(sa.curve, sb.curve) <= 0.05
        end
      end

      assert length(Drawing.shapes(original)) == length(Drawing.shapes(again))

      assert Enum.map(again.children, & &1.attributes) ==
               Enum.map(original.children, & &1.attributes)
    end
  end

  @transforms [
    "",
    "translate(3 -2)",
    "scale(2 0.5)",
    "rotate(30 1 1)",
    "skewX(20)",
    "scale(-1 1)",
    "matrix(1 0.5 -0.3 1.2 4 5)"
  ]

  @spec matrix_close?(tuple(), tuple()) :: boolean()
  defp matrix_close?(a, b) do
    Enum.zip(Tuple.to_list(a), Tuple.to_list(b))
    |> Enum.all?(fn {x, y} -> abs(x - y) <= 1.0e-9 * max(1.0, abs(x)) end)
  end

  property "nested groups are drawn with their own transforms, so a drawing reads back the same" do
    check all(
            [outer, inner, own] <-
              StreamData.list_of(StreamData.member_of(@transforms), length: 3),
            shape <-
              StreamData.member_of([
                ~s|<circle cx="2" cy="1" r="4"/>|,
                ~s|<polygon points="0,0 4,1 2,5"/>|,
                ~s|<path d="M0 0 L10 0 A5 3 30 0 1 10 10 z"/>|
              ])
          ) do
      original =
        Curves.from_svg(
          ~s|<svg><g id="a" transform="#{outer}" clip-path="url(#c)"><g id="b" transform="#{inner}"><text>T</text>| <>
            String.replace(shape, "/>", ~s| transform="#{own}"/>|) <> "</g></g></svg>"
        )

      svg = Curves.Svg.render(original)
      again = Curves.from_svg(svg)

      # Each group keeps its own transform, so whatever is in it (a clip-path, text) is where it was.
      for id <- ["a", "b"] do
        assert matrix_close?(
                 Drawing.get(original, id).transform,
                 Drawing.get(again, id).transform
               )
      end

      [a] = Drawing.shapes(original)
      [b] = Drawing.shapes(again)
      assert matrix_close?(a.transform, b.transform)

      for {sa, sb} <- Enum.zip(a.subpaths, b.subpaths) do
        # Samples are this far apart at most, relative to the curve's size.
        %{xmin: xmin, xmax: xmax, ymin: ymin, ymax: ymax} =
          Curves.Utils.Vec.bounds(Curves.take!(sa.curve, 100))

        assert furthest(sa.curve, sb.curve) <= 0.01 * max(1.0, max(xmax - xmin, ymax - ymin))
      end

      # Text inside a group is drawn inside it, with no transform of its own added.
      assert svg =~ "\n<text>T</text>"
    end
  end

  property "any attribute value, with line breaks and tabs, reads back the same after drawing" do
    check all(
            value <-
              StreamData.string([?\n, ?\t, ?\r, ?&, ?<, ?>, ?", ?', ?\s, ?a..?z, 0x00E0..0x00FF])
          ) do
      escaped = Curves.Svg.Import.escape(value)
      drawing = Curves.from_svg(~s|<svg><circle r="1" data-x="#{escaped}"/></svg>|)
      [shape] = Drawing.shapes(drawing)
      assert shape.attributes["data-x"] == value

      [again] = drawing |> Curves.Svg.render() |> Curves.from_svg() |> Drawing.shapes()
      assert again.attributes["data-x"] == value
    end
  end

  property "a comma may separate repeated sets of arguments, as SVG allows" do
    check all(
            points <-
              StreamData.list_of(
                StreamData.tuple({StreamData.integer(-50..50), StreamData.integer(-50..50)}),
                min_length: 2,
                max_length: 8
              ),
            letter <- StreamData.member_of(["M", "L"]),
            separator <- StreamData.member_of([",", " , ", ", ", " ,"])
          ) do
      [{x0, y0} | rest] = points
      repeated = Enum.map_join(rest, separator, fn {x, y} -> "#{x},#{y}" end)
      start = if letter == "M", do: "M#{x0},#{y0}#{separator}", else: "M#{x0},#{y0} L"
      [subpath] = Curves.from_svg_path(start <> repeated)

      points
      |> Enum.with_index()
      |> Enum.each(fn {{x, y}, i} ->
        assert Curves.solve!(subpath.curve, i * 1.0) == {x * 1.0, y * 1.0}
      end)
    end
  end
end
