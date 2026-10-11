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
            hermite
          ] do
        svg = Svg.render(define.(@b_spline))
        assert length(line_points(svg)) == 101
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
      curve = Curves.define_bezier(:linear)
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

    test "save!/3 writes the file and returns the path" do
      path = Path.join(System.tmp_dir!(), "curves_svg_save_test.svg")
      assert Svg.save!(Curves.define_bezier(:linear), path, samples: 3) == path
      assert path |> File.read!() |> line_points() |> length() == 4
    end
  end

  # How many times `part` appears in `text`.
  @spec count(String.t(), String.t()) :: non_neg_integer()
  defp count(text, part), do: length(String.split(text, part)) - 1
end
