defmodule Curves.Svg.ImportTest do
  use ExUnit.Case, async: true
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Raw, Shape, Subpath}

  # Reads the shapes inside an <svg>.
  @spec read(String.t(), keyword()) :: Drawing.t()
  defp read(body, opts \\ []), do: Curves.from_svg("<svg>" <> body <> "</svg>", opts)

  # The only curve in a drawing.
  @spec only_curve(Drawing.t()) :: Curves.Types.curve_struct()
  defp only_curve(drawing) do
    [curve] = Drawing.curves(drawing)
    curve
  end

  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  describe "the document" do
    test "reads the <svg> element's size and view box" do
      drawing = Curves.from_svg(~s|<svg width="10cm" height="5" viewBox="0,0 100 50"></svg>|)

      assert {drawing.width, drawing.height, drawing.view_box} ==
               {"10cm", "5", {0.0, 0.0, 100.0, 50.0}}

      assert Drawing.shapes(drawing) == []
      assert Curves.from_svg(~s|<svg viewBox="nonsense"/>|).view_box == nil
    end

    test "something without an <svg> element, or that isn't a string, raises an ArgumentError" do
      assert_raise ArgumentError, "expected an SVG document, but found no <svg> element", fn ->
        Curves.from_svg("<html><path d='M0 0 L1 1'/></html>")
      end

      assert_raise ArgumentError, ~r/expected an SVG document as a string/, fn ->
        Curves.from_svg(nil)
      end
    end

    test "skips comments, CDATA, <?xml?> and DOCTYPE (with an internal subset), and reads svg: prefixes" do
      svg = """
      <?xml version="1.0"?>
      <!DOCTYPE svg [ <!ENTITY e "x"> <!-- > --> ]>
      <!-- <path d="M0 0 L9 9"/> -->
      <svg:svg xmlns:svg="http://www.w3.org/2000/svg">
        <![CDATA[ <path d="M0 0 L9 9"/> ]]>
        <svg:line x2="1"/>
      </svg:svg>
      """

      assert [%Shape{element: :line}] = Drawing.shapes(Curves.from_svg(svg))
    end

    test "a > inside a quoted attribute doesn't end the tag, and entities are decoded" do
      drawing = read(~s|<line id="a&gt;b" data-x='1 > 0' x2="&#53;"/>|)
      assert [%Shape{id: "a>b", attributes: %{"data-x" => "1 > 0"}}] = Drawing.shapes(drawing)
      assert_near(Curves.solve!(only_curve(drawing), 1.0), {5.0, 0.0})
    end

    test "content in <defs>, <symbol>, <clipPath>, <mask>, <marker> and <title> isn't read as shapes, but kept" do
      tags = ~w(defs symbol clipPath mask marker pattern title style)

      body =
        for tag <- tags, into: "" do
          ~s|<#{tag}><line x2="1"/><g><line x2="1"/></g></#{tag}>|
        end

      drawing = read(body)
      assert Drawing.shapes(drawing) == []
      assert drawing.skipped == []
      assert Enum.map(drawing.children, & &1.element) == tags

      assert hd(drawing.children) == %Raw{
               element: "defs",
               markup: ~s|<defs><line x2="1"/><g><line x2="1"/></g></defs>|
             }
    end

    test "text, images, use and nested svg are kept as markup, and listed as skipped" do
      drawing =
        read(~s|<text id="t">Hi<tspan/></text><image/><use href="#x"/><svg><line x2="1"/></svg>|)

      assert Drawing.shapes(drawing) == []

      assert drawing.skipped == [
               %{element: "text", id: "t", reason: :not_supported},
               %{element: "image", id: nil, reason: :not_supported},
               %{element: "use", id: nil, reason: :not_supported},
               %{element: "svg", id: nil, reason: :not_supported}
             ]

      assert Enum.map(drawing.children, & &1.markup) == [
               ~s|<text id="t">Hi<tspan/></text>|,
               "<image/>",
               ~s|<use href="#x"/>|,
               ~s|<svg><line x2="1"/></svg>|
             ]
    end

    test "groups are kept, with their attributes but not their transform" do
      drawing =
        read(
          ~s|<g id="outer" opacity="0.5" transform="scale(2)"><g><circle r="1"/></g><text>A</text></g>|
        )

      assert [%Group{id: "outer", attributes: attributes, children: [inner, text]}] =
               drawing.children

      assert %Group{children: [%Shape{}]} = inner
      assert attributes == %{"id" => "outer", "opacity" => "0.5"}
      # The kept text's group transform is kept with it
      assert %Raw{transform: {2.0, +0.0, +0.0, 2.0, +0.0, +0.0}} = text
    end

    test "shapes Curves can't measure, and anything with an unreadable transform, are kept as markup" do
      drawing =
        read(
          ~s|<rect width="10%" height="5"/><g transform="spin(3)"><line x2="1"/></g><circle r="0"/>|
        )

      assert Drawing.shapes(drawing) == []

      assert [
               %Raw{element: "rect", markup: ~s|<rect width="10%" height="5"/>|},
               %Raw{element: "g"}
             ] =
               drawing.children

      assert Enum.map(drawing.skipped, & &1.reason) == [
               {:unsupported_unit, "10%"},
               {:invalid_transform, ~s|can't read the transform "spin(3)"|},
               :empty
             ]
    end

    test "disguised javascript: links, animations of links and handlers, and invalid names are taken out" do
      drawing =
        read(
          ~s|<text><a href=" jav&#x09;ascript:x()">A</a></text>| <>
            ~s|<a><set attributeName="href" to="javascript:x()"/><animate attributeName="onclick"/><animate attributeName="opacity"/></a>| <>
            ~s|<text x;y="1" fill="red"><bad;name/>B</text>|
        )

      markup = Enum.map_join(drawing.children, &Map.get(&1, :markup, ""))
      assert markup =~ ~s|<text><a>A</a></text>|
      refute markup =~ "set"
      refute markup =~ "onclick"
      assert markup =~ ~s|<text fill="red">B</text>|
      assert Curves.Svg.render(drawing) =~ ~s|<animate attributeName="opacity"/>|
    end

    test "kept markup is well formed: open tags are closed, stray and unfinished ones left out" do
      drawing = read(~s|<defs><g><rect/></defs><text>a</b>c|)

      assert [%Raw{markup: "<defs><g><rect/></g></defs>"}, %Raw{markup: "<text>ac</text>"}] =
               drawing.children
    end

    test "shapes keep every transform that applied to them" do
      [shape] =
        Drawing.shapes(
          read(~s|<g transform="translate(1 2)"><line x2="1" transform="scale(3)"/></g>|)
        )

      assert shape.transform == {3.0, 0.0, 0.0, 3.0, 1.0, 2.0}
    end

    test "scripts, foreign objects, event attributes and javascript: links are never kept" do
      drawing =
        read(
          ~s|<script>alert(1)</script><text onclick="x()" fill="red">Hi<script>bad()</script></text>| <>
            ~s|<a href="javascript:x()"><line x2="1"/></a><foreignObject><div/></foreignObject>|
        )

      markup = Enum.map_join(drawing.children, &Map.get(&1, :markup, ""))
      refute markup =~ "script"
      refute markup =~ "onclick"
      assert markup =~ ~s|<text fill="red">Hi</text>|
      svg = Curves.Svg.render(drawing)
      refute svg =~ "javascript"
      refute svg =~ "script"
      refute svg =~ "foreignObject"
      assert svg =~ "<a>"
      assert Enum.map(drawing.skipped, & &1.element) == ["script", "text", "foreignObject"]
    end

    test "broken markup: stray closing tags, unclosed tags, and anything after </svg>" do
      assert [_] = Drawing.shapes(read(~s|</g><line x2="1"/></p>|))
      assert [_] = Drawing.shapes(Curves.from_svg(~s|<svg><g><line x2="1"/>|))
      assert [_] = Drawing.shapes(Curves.from_svg(~s|<svg><line x2="1"/></svg><line x2="2"/>|))
      assert [] = Drawing.shapes(Curves.from_svg(~s(<svg><line x2="1")))
      assert [] = Drawing.shapes(Curves.from_svg(~s|<svg><!-- never closed <line x2="1"/>|))
    end
  end

  describe "shapes" do
    test "a path: one subpath per M, closed with Z or not" do
      drawing =
        read(~s|<path id="o" d="M0 0 h4 v4 h-4 z M1 1 h2 v2 h-2 z M9 9 L10 10" fill="red"/>|)

      assert [%Shape{element: :path, id: "o", attributes: %{"fill" => "red"}, subpaths: subpaths}] =
               Drawing.shapes(drawing)

      assert Enum.map(subpaths, & &1.closed) == [true, true, false]
    end

    test "a rect, with SVG's rules for rounded corners" do
      square = only_curve(read(~s|<rect x="1" y="2" width="4" height="3"/>|))
      assert Curves.max_u(square) == 4.0
      assert Curves.solve!(square, 0.0) == {1.0, 2.0}
      assert Curves.solve!(square, 1.0) == {5.0, 2.0}

      # rx only: ry is the same. The path starts after the top-left corner.
      round = only_curve(read(~s|<rect width="10" height="6" rx="2"/>|))
      assert Curves.solve!(round, 0.0) == {2.0, 0.0}
      assert Curves.max_u(round) == 8.0

      # Corners as big as the side leave no straight part: a circle made of 4 arcs.
      circle = only_curve(read(~s|<rect width="4" height="4" rx="9"/>|))
      assert Curves.max_u(circle) == 4.0

      assert_near(
        Curves.solve!(circle, 0.5),
        {2.0 + 2 * :math.sqrt(0.5), 2.0 - 2 * :math.sqrt(0.5)}
      )
    end

    test "circles and ellipses start at the right end of their x axis" do
      assert_near(
        Curves.solve!(only_curve(read(~s|<circle cx="1" cy="1" r="2"/>|)), 0.0),
        {3.0, 1.0}
      )

      ellipse = only_curve(read(~s|<ellipse cx="0" cy="0" rx="4" ry="2"/>|))
      assert_near(Curves.solve!(ellipse, 0.25), {0.0, 2.0})
      # A missing ry is the same as rx (SVG 2)
      auto = only_curve(read(~s|<ellipse rx="3"/>|))
      assert_near(Curves.solve!(auto, 0.25), {0.0, 3.0})
    end

    test "lines, polylines and polygons are polylines; a polygon closes itself" do
      assert [%Subpath{closed: false}] =
               hd(Drawing.shapes(read(~s|<line x1="1" y1="1" x2="4" y2="5"/>|))).subpaths

      polygon = read(~s|<polygon points="0,0 4,0 4,3"/>|)
      assert [%Subpath{curve: curve, closed: true}] = hd(Drawing.shapes(polygon)).subpaths
      assert Curves.max_u(curve) == 3.0
      assert Curves.solve!(curve, 3.0) == {0.0, 0.0}

      assert Curves.max_u(only_curve(read(~s|<polyline points="0 0 1 1 2 0"/>|))) == 2.0
    end

    test "missing positions are 0, and px is read" do
      assert_near(Curves.solve!(only_curve(read(~s|<line x2="5px"/>|)), 1.0), {5.0, 0.0})
    end
  end

  describe "what's skipped, and why" do
    test "shapes SVG doesn't draw are :empty" do
      body =
        ~s|<circle r="0"/><ellipse rx="0" ry="2"/><rect width="0" height="3"/><polyline points=""/><path d=""/>|

      drawing = read(body)
      assert Drawing.shapes(drawing) == []
      assert Enum.map(drawing.skipped, & &1.reason) == [:empty, :empty, :empty, :empty]
    end

    test "negative sizes are invalid; units other than px aren't supported" do
      drawing =
        read(
          ~s|<circle r="-1"/><rect width="10%" height="5"/><rect width="5" height="5" rx="-1"/><line x2="3em"/>|
        )

      assert Enum.map(drawing.skipped, & &1.reason) == [
               {:invalid, "r can't be negative, got: -1.0"},
               {:unsupported_unit, "10%"},
               {:invalid, "rx can't be negative, got: -1.0"},
               {:unsupported_unit, "3em"}
             ]
    end

    test "bad path data keeps what came before, and is listed" do
      drawing = read(~s|<path id="p" d="M0 0 L1 1 M5 5 L"/>|)
      assert [%Shape{subpaths: [_]}] = Drawing.shapes(drawing)
      assert [%{element: "path", id: "p", reason: {:invalid_path, _}}] = drawing.skipped
    end

    test "an odd number of polyline coordinates keeps the pairs, and is listed" do
      drawing = read(~s|<polyline points="0 0 1 1 2"/>|)
      assert Curves.max_u(only_curve(drawing)) == 1.0
      assert [%{reason: {:invalid, "points: an odd number of coordinates"}}] = drawing.skipped
    end

    test "an unreadable transform skips the element, or a whole group" do
      drawing =
        read(
          ~s|<line x2="1" transform="spin(3)"/><g transform="oops"><line x2="1"/><circle r="1"/></g>|
        )

      assert Drawing.shapes(drawing) == []

      assert [
               %{element: "line", reason: {:invalid_transform, _}},
               %{element: "g", reason: {:invalid_transform, _}}
             ] = drawing.skipped
    end
  end

  describe "transforms" do
    test "a shape's transform comes after its groups' (applied right to left)" do
      drawing =
        read(
          ~s|<g transform="translate(10 0)"><g transform="scale(2)"><line x2="1" transform="rotate(90)"/></g></g>|
        )

      assert_near(Curves.solve!(only_curve(drawing), 1.0), {10.0, 2.0})
    end

    test "the root <svg>'s own transform counts too" do
      drawing = Curves.from_svg(~s|<svg transform="translate(0 5)"><line x2="1"/></svg>|)
      assert_near(Curves.solve!(only_curve(drawing), 1.0), {1.0, 5.0})
    end

    test "a skewed circle is exact: each point is the skew of the circle's point" do
      circle = only_curve(read(~s|<circle r="2"/>|))
      skewed = only_curve(read(~s|<circle r="2" transform="skewX(30)"/>|))
      tan = :math.tan(:math.pi() / 6)

      for u <- [0.1, 0.33, 0.5, 0.9] do
        {x, y} = Curves.solve!(circle, u)
        assert_near(Curves.solve!(skewed, u), {x + tan * y, y})
      end
    end

    test "flip_y: true mirrors every y" do
      drawing = read(~s|<g transform="translate(0 3)"><path d="M0 0 L2 4"/></g>|, flip_y: true)
      assert_near(Curves.solve!(only_curve(drawing), 1.0), {2.0, -7.0})
      [subpath] = Curves.from_svg_path("M0 0 L2 4", flip_y: true)
      assert_near(Curves.solve!(subpath.curve, 1.0), {2.0, -4.0})
    end
  end

  test "from_svg_path/2 raises on bad path data, or on something that isn't a string" do
    assert_raise ArgumentError,
                 "invalid path data: path data must start with M or m, got: \"Q\"",
                 fn ->
                   Curves.from_svg_path("Q")
                 end

    assert_raise ArgumentError, ~r/expected SVG path data as a string/, fn ->
      Curves.from_svg_path(nil)
    end
  end
end
