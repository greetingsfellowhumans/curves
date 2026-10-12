defmodule Curves.SvgTest do
  use ExUnit.Case
  alias Curves.Svg
  doctest Svg

  @b_spline [{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}]

  # Every "x,y" pair inside the first <polyline points="..."> of the SVG.
  @spec line_points(String.t()) :: list({float(), float()})
  defp line_points(svg) do
    [_, points] = Regex.run(~r/<polyline points="([^"]+)" fill="none" stroke="#1c7ed6"/, svg)

    for pair <- String.split(points, " ") do
      [x, y] = String.split(pair, ",")
      {String.to_float(x), String.to_float(y)}
    end
  end

  # The numbers along the bottom edge, left to right.
  @spec x_labels(String.t()) :: list(String.t())
  defp x_labels(svg) do
    for [_, label] <- Regex.scan(~r/<text [^>]*text-anchor="middle"[^>]*>([^<]+)</, svg),
        do: label
  end

  describe "render/2" do
    test "draws samples + 1 points, starting at the start of the curve" do
      svg =
        Svg.render(Curves.define_bezier(:linear), samples: 4, width: 100, height: 100, padding: 0)

      assert line_points(svg) == [
               {0.0, 100.0},
               {25.0, 75.0},
               {50.0, 50.0},
               {75.0, 25.0},
               {100.0, 0.0}
             ]
    end

    test "works for every spline type, with 100 samples by default" do
      hermite = fn points -> points |> Enum.map(&[&1, {1, 1}]) |> Curves.define_hermite() end

      for define <- [
            &Curves.define_b_spline/1,
            &Curves.define_catmull_rom/1,
            hermite,
            &Curves.define_cardinal/1,
            &Curves.define_centripetal_catmull_rom/1,
            &Curves.define_kochanek_bartels/1,
            &Curves.define_natural_cubic/1
          ] do
        svg = Svg.render(define.(@b_spline))
        assert length(line_points(svg)) == 101
      end

      # A monotone spline's knots are data points, with x always increasing.
      svg = Svg.render(Curves.define_monotone([{0, 0}, {1, 2}, {2, 1}, {3, 3}]))
      assert length(line_points(svg)) == 101
    end

    test "an ellipse draws the box around it as dots, with dashed lines like a quadratic's" do
      svg = Svg.render(Curves.define_ellipse({0, 0}, {4, 2}), samples: 10)
      # Its start and end are the same point, drawn twice.
      assert count(svg, "<circle") == 9
      assert count(svg, "stroke-dasharray") == 4
      assert length(line_points(svg)) == 11
    end

    test "the splines built from knots draw one dot per knot, and a dashed line through them" do
      for define <- [
            &Curves.define_cardinal/1,
            &Curves.define_centripetal_catmull_rom/1,
            &Curves.define_kochanek_bartels/1,
            &Curves.define_natural_cubic/1
          ] do
        svg = Svg.render(define.(@b_spline), samples: 10)
        assert count(svg, "<circle") == 6
        assert count(svg, "stroke-dasharray") == 1
      end
    end

    test "keeps everything inside the image" do
      svg =
        Svg.render(Curves.define_b_spline(@b_spline), width: 300, height: 200, padding: 10)

      for {x, y} <- line_points(svg) do
        assert x >= 10.0 and x <= 290.0
        assert y >= 10.0 and y <= 190.0
      end
    end

    test "draws one dot per point, and no dots when turned off" do
      curve = Curves.define_catmull_rom(@b_spline)
      assert Svg.render(curve, samples: 10) |> count("<circle") == 6
      assert Svg.render(curve, samples: 10, show_points: false) |> count("<circle") == 0
    end

    test "dots follow the curve when it is moved" do
      curve =
        Curves.define_bezier([{0, 0}, {10, 10}]) |> Curves.Transform.set_position({100, 100})

      svg = Svg.render(curve, samples: 2, width: 100, height: 100, padding: 0)
      assert svg =~ ~s(<circle cx="0.00" cy="100.00")
      assert svg =~ ~s(<circle cx="100.00" cy="0.00")
    end

    test "a flat curve doesn't divide by zero" do
      svg =
        Svg.render(Curves.define_bezier(:linear_horizontal),
          samples: 2,
          width: 100,
          height: 100,
          padding: 0
        )

      assert line_points(svg) == [{0.0, 50.0}, {50.0, 50.0}, {100.0, 50.0}]
    end

    test "a curve that is a single point is drawn at the centre" do
      curve = Curves.define_bezier([{100, -100}, {100, -100}])
      svg = Svg.render(curve, samples: 2, width: 100, height: 100)
      assert line_points(svg) == [{50.0, 50.0}, {50.0, 50.0}, {50.0, 50.0}]
    end

    test "optional parts" do
      # A cubic, so it has control lines (a straight line has none).
      curve = Curves.define_bezier(:ease)
      assert Svg.render(curve, samples: 2) =~ "stroke-dasharray"
      refute Svg.render(curve, samples: 2, show_polygon: false) =~ "stroke-dasharray"
      refute Svg.render(curve, samples: 2, background: nil) =~ "<rect"

      assert Svg.render(curve, samples: 2, title: "a < b & \"c\"") =~
               "a &lt; b &amp; &quot;c&quot;</text>"
    end

    test "curve_color and curve_width style the curve" do
      svg = Svg.render(Curves.define_bezier(:linear), curve_color: "#123456", curve_width: 7)
      assert svg =~ ~s(fill="none" stroke="#123456" stroke-width="7")
    end

    test "passes solve_opts through" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])

      svg =
        Svg.render(curve,
          samples: 2,
          solve_opts: [force_percent: true],
          show_points: false,
          show_polygon: false,
          width: 100,
          height: 100,
          padding: 0
        )

      assert line_points(svg) == [{0.0, 100.0}, {50.0, 50.0}, {100.0, 0.0}]
    end

    test "raises a clear error on a bad sample count" do
      for bad <- [0, -1, 2.5, nil] do
        assert_raise ArgumentError, ~r/:samples must be a positive integer/, fn ->
          Svg.render(Curves.define_bezier(:linear), samples: bad)
        end
      end
    end

    test "axes by default, and show_axes: false turns them off" do
      curve = Curves.define_bezier(:linear)
      assert Svg.render(curve) =~ "<line"
      assert Svg.render(curve) == Svg.render(curve, show_axes: true)
      refute Svg.render(curve, show_axes: false) =~ "<line"
    end

    test "axes label round numbers, so a scaled curve shows bigger values" do
      curve = Curves.define_bezier(:linear)
      assert x_labels(Svg.render(curve, show_axes: true)) == ~w(0.0 0.2 0.4 0.6 0.8 1.0)

      big = Curves.Transform.set_scale(curve, 10)
      assert x_labels(Svg.render(big, show_axes: true)) == ~w(0 2 4 6 8 10)
    end

    test "axes follow a moved curve, including negative values" do
      curve = Curves.define_bezier([{-300, -300}, {300, 300}])
      labels = x_labels(Svg.render(curve, show_axes: true))
      assert labels == ~w(-300 -200 -100 0 100 200 300)
      refute "-0" in labels
    end

    test "the x = 0 and y = 0 lines are darker" do
      svg = Svg.render(Curves.define_bezier([{-1, -1}, {1, 1}]), show_axes: true)
      assert length(Regex.scan(~r/<line [^>]*stroke-opacity="0.9"/, svg)) == 2
    end

    test "axis_color colours the grid and is escaped" do
      svg = Svg.render(Curves.define_bezier(:linear), show_axes: true, axis_color: "red\"")
      assert svg =~ ~s(stroke="red&quot;")
      refute svg =~ ~s(stroke="#868e96")
    end

    test "axes work for flat curves, single points, and padding that fills the image" do
      for curve <- [
            Curves.define_bezier([{0, 1}, {5, 1}]),
            Curves.define_bezier([{2, 2}, {2, 2}])
          ] do
        assert Svg.render(curve, show_axes: true) =~ "<line"
      end

      for padding <- [50, 60] do
        svg =
          Svg.render(Curves.define_bezier(:linear),
            show_axes: true,
            width: 100,
            height: 100,
            padding: padding
          )

        refute svg =~ "<line"
      end
    end

    test "dashed lines go from each control point to the point it pulls on" do
      dashed = fn curve ->
        svg = Svg.render(curve, width: 100, height: 100, padding: 0, show_axes: false)

        for [_, points] <- Regex.scan(~r/<polyline points="([^"]+)"[^>]*stroke-dasharray/, svg),
            do: points |> String.split(" ") |> length()
      end

      # Cubic: start to c0, and c1 to end. Quadratic: start to c to end. Line: none.
      assert dashed.(Curves.define_bezier([{0, 0}, {1, 3}, {2, -1}, {3, 1}])) == [2, 2]
      assert dashed.(Curves.define_bezier([{0, 0}, {1, 3}, {2, 0}])) == [3]
      assert dashed.(Curves.define_bezier([{0, 0}, {1, 3}])) == []

      # A bezier spline: the same for each curve, with nothing for its straight part.
      spline =
        Curves.define_bezier_spline([
          [{0, 0}, {1, 3}, {2, -1}],
          [{3, 1}, {4, 4}],
          [{5, 0}],
          [{6, 1}]
        ])

      assert dashed.(spline) == [2, 2, 3]

      # Other splines still get one line through their points.
      assert dashed.(Curves.define_catmull_rom(@b_spline)) == [6]
    end

    test "markers highlight extra points, and the image grows to fit them" do
      curve = Curves.define_bezier(:linear)
      plain = Svg.render(curve, width: 100, height: 100, padding: 0, show_axes: false)
      refute plain =~ "#7048e8"

      svg =
        Svg.render(curve,
          markers: [Curves.solve!(curve, 0.5)],
          width: 100,
          height: 100,
          padding: 0
        )

      assert svg =~ ~s(<circle cx="50.00" cy="50.00" r="7" fill="#7048e8" stroke="#ffffff")

      # A marker outside the curve widens the view: x spans 0..2 (50 px per unit), so the end
      # {1, 1} lands halfway across, and y (0..1) is centred vertically.
      wide =
        Svg.render(curve,
          markers: [{2, 1}],
          width: 100,
          height: 100,
          padding: 0,
          show_axes: false
        )

      assert List.last(line_points(wide)) == {50.0, 25.0}
    end

    test "a fixed view draws the same area whatever the curve's size" do
      opts = [width: 100, height: 100, padding: 0, show_axes: false, view: {{0, 0}, {10, 10}}]
      small = Curves.define_bezier([{0, 0}, {1, 1}])
      big = Curves.Transform.set_scale(small, 5)

      assert List.last(line_points(Svg.render(small, opts))) == {10.0, 90.0}
      assert List.last(line_points(Svg.render(big, opts))) == {50.0, 50.0}
    end

    test "view must be two corners" do
      assert_raise ArgumentError, ~r/:view must be two corners/, fn ->
        Svg.render(Curves.define_bezier(:linear), view: {0, 10})
      end
    end

    test "markers must be {x, y} points" do
      assert_raise ArgumentError, ~r/expected an \{x, y\} point with numbers, got: :nope/, fn ->
        Svg.render(Curves.define_bezier(:linear), markers: [:nope])
      end
    end

    test "save!/3 writes the file and returns the path" do
      path = Path.join(System.tmp_dir!(), "curves_svg_save_test.svg")
      assert Svg.save!(Curves.define_bezier(:linear), path, samples: 3) == path
      assert path |> File.read!() |> line_points() |> length() == 4
    end

    test "save!/2 uses the default options" do
      path = Path.join(System.tmp_dir!(), "curves_svg_save_default_test.svg")
      curve = Curves.define_bezier(:linear)
      assert Svg.save!(curve, path) == path
      assert File.read!(path) == Svg.render(curve)
    end
  end

  # How many times `part` appears in `text`.
  @spec count(String.t(), String.t()) :: non_neg_integer()
  defp count(text, part), do: length(String.split(text, part)) - 1

  describe "drawings, in :inspect mode" do
    @drawing ~s|<svg><circle cx="5" cy="5" r="2"/><path d="M0 0 L10 0 M0 10 L10 10"/><line x2="3"/></svg>|

    # Every "x,y" pair of every curve line (they are drawn in the curve colour).
    @spec curve_lines(String.t()) :: list(list({float(), float()}))
    defp curve_lines(svg) do
      for [_, line] <-
            Regex.scan(~r/<polyline points="([^"]+)" fill="none" stroke="#1c7ed6"/, svg) do
        for pair <- String.split(line, " "),
            do: pair |> String.split(",") |> Enum.map(&String.to_float/1) |> List.to_tuple()
      end
    end

    test "draws every curve of a drawing, fitted together, with every curve's dots" do
      drawing = Curves.from_svg(@drawing)
      svg = Svg.render(drawing, mode: :inspect, samples: 20, width: 300, height: 200, padding: 10)
      lines = curve_lines(svg)
      assert length(lines) == 4
      assert Enum.all?(lines, &(length(&1) == 21))

      for line <- lines, {x, y} <- line do
        assert x >= 9.99 and x <= 290.01
        assert y >= 9.99 and y <= 190.01
      end

      # 9 for the circle (the box around it), 2 + 2 for the path, 2 for the line
      assert count(svg, "<circle") == 15
    end

    test "is the same picture as its curves, one by one, in the same place" do
      drawing = Curves.from_svg(~s|<svg><line x1="1" y1="1" x2="4" y2="5"/></svg>|)
      [curve] = Curves.Drawing.curves(drawing)
      assert Svg.render(drawing, mode: :inspect) == Svg.render(curve)
    end

    test "a drawing with nothing in it is an empty picture" do
      svg =
        Svg.render(Curves.from_svg("<svg><text>Hi</text></svg>"), mode: :inspect, title: "Empty")

      assert svg =~ "Empty"
      assert curve_lines(svg) == []
    end
  end

  describe "drawings, as designed (the default)" do
    @designed """
    <svg width="400" height="300" viewBox="0 0 200 150" xmlns:xlink="http://www.w3.org/1999/xlink">
      <defs><linearGradient id="fade"><stop offset="0" stop-color="red"/></linearGradient></defs>
      <rect x="10" y="10" width="50" height="30" rx="5" fill="url(#fade)" stroke="black" class="box"/>
      <g opacity="0.5" transform="translate(100 50) scale(2)">
        <circle r="10" fill="orange" stroke-width="3" stroke="blue"/>
        <text x="0" y="20">Hello &amp; bye</text>
      </g>
      <path d="M0 140 L200 140" stroke="green" onclick="bad()"/>
    </svg>
    """

    test "keeps the size, view box, groups, styles and markup, and adds no dots or grid" do
      svg = Svg.render(Curves.from_svg(@designed))
      assert svg =~ ~s(width="400" height="300" viewBox="0.0 0.0 200.0 150.0")
      assert svg =~ ~s(xmlns:xlink="http://www.w3.org/1999/xlink")

      assert svg =~
               ~s(<defs><linearGradient id="fade"><stop offset="0" stop-color="red"/></linearGradient></defs>)

      assert svg =~ ~s|class="box" fill="url(#fade)" stroke="black"/>|
      assert svg =~ ~s(<g opacity="0.5">)
      assert svg =~ "Hello &amp; bye"
      refute svg =~ "onclick"
      refute svg =~ "<circle"
      refute svg =~ "stroke-dasharray"
    end

    test "a transformed shape is drawn in its own coordinates, with its transform, so strokes scale" do
      svg = Svg.render(Curves.from_svg(@designed))

      assert svg =~
               ~s|transform="matrix(2.0 0.0 0.0 2.0 100.0 50.0)" fill="orange" stroke="blue" stroke-width="3"/>|

      [_, d] = Regex.run(~r{<path d="([^"]+)" transform="matrix\(2}, svg)
      assert String.starts_with?(d, "M10.0,0.0 A10.0 10.0")
      # Kept text gets its group's transform around it
      assert svg =~ ~s|<g transform="matrix(2.0 0.0 0.0 2.0 100.0 50.0)"><text x="0" y="20">|
    end

    test "dots, dashed lines, markers and a title can be turned on, in the drawing's units" do
      svg =
        Svg.render(Curves.from_svg(@designed),
          show_points: true,
          show_polygon: true,
          markers: [{1, 2}],
          title: "T"
        )

      assert count(svg, "<circle") > 1
      assert svg =~ "stroke-dasharray"
      # 7 pixels at 2 pixels per unit
      assert svg =~ ~s(<circle cx="1.0" cy="2.0" r="3.5")
      assert svg =~ ">T</text>"
    end

    test ":width, :height, :view and :background change the picture's frame" do
      svg =
        Svg.render(Curves.from_svg(@designed),
          width: 100,
          height: 75,
          view: {{0, 0}, {50, 50}},
          background: "#eee"
        )

      assert svg =~ ~s(width="100" height="75" viewBox="0.0 0.0 50.0 50.0")
      assert svg =~ ~s(<rect x="0.0" y="0.0" width="50.0" height="50.0" fill="#eee"/>)
    end

    test "with no view box, it fits the curves; a flipped drawing's view box is flipped" do
      svg = Svg.render(Curves.from_svg(~s|<svg><line x1="1" y1="2" x2="5" y2="10"/></svg>|))
      assert svg =~ ~s(viewBox="1.0 2.0 4.0 8.0")
      flipped = Curves.from_svg(~s|<svg viewBox="0 0 10 20"><line x2="3"/></svg>|, flip_y: true)
      assert flipped.view_box == {0.0, -20.0, 10.0, 20.0}
    end

    test "save! writes it, and :mode is checked" do
      path = Path.join(System.tmp_dir!(), "curves_drawing_test.svg")
      assert Svg.save!(Curves.from_svg(@designed), path) == path
      assert File.read!(path) == Svg.render(Curves.from_svg(@designed))

      assert_raise ArgumentError, ":mode must be :design or :inspect, got: :pretty", fn ->
        Svg.render(Curves.from_svg(@designed), mode: :pretty)
      end

      assert_raise ArgumentError, ~r/:mode must be :inspect for a curve/, fn ->
        Svg.render(Curves.define_bezier(:linear), mode: :design)
      end
    end
  end

  describe "path_data/1" do
    test "every kind of curve, exactly, with its transforms" do
      assert Svg.path_data(Curves.define_bezier([{0, 0}, {1, 1}])) == "M0.0,0.0 L1.0,1.0"

      assert Svg.path_data(Curves.define_bezier([{0, 0}, {1, 1}, {2, 0}])) ==
               "M0.0,0.0 Q1.0,1.0 2.0,0.0"

      assert Svg.path_data(
               Curves.define_bezier_spline([[{0, 0}], [{3, 0}, {4, 1}, {5, 1}], [{6, 0}]])
             ) ==
               "M0.0,0.0 L3.0,0.0 C4.0,1.0 5.0,1.0 6.0,0.0"

      moved = Curves.define_polyline([{0, 0}, {1, 0}]) |> Curves.Transform.set_position({1, 1})
      assert Svg.path_data(moved) == "M1.0,1.0 L2.0,1.0"
    end

    test "a whole circle is written in pieces, since one A can't start and end in the same place" do
      d = Svg.path_data(Curves.define_circle({0, 0}, 2))
      assert d |> String.split("A") |> length() == 4
      assert String.ends_with?(d, " 2.0,0.0")
    end

    test "a curve that can't be path data raises" do
      assert_raise ArgumentError, ~r/1 to 4 points/, fn ->
        Svg.path_data(Curves.define_bezier([{0, 0}, {1, 1}, {2, 2}, {3, 3}, {4, 4}]))
      end
    end
  end
end
