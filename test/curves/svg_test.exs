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

  describe "render/3" do
    test "draws samples + 1 points, starting at the start of the curve" do
      svg = Svg.render(Curves.define_bezier(:linear), 4, width: 100, height: 100, padding: 0)

      assert line_points(svg) == [
               {0.0, 100.0},
               {25.0, 75.0},
               {50.0, 50.0},
               {75.0, 25.0},
               {100.0, 0.0}
             ]
    end

    test "works for every spline type" do
      for define <- [
            &Curves.define_b_spline/1,
            &Curves.define_catmull_rom/1,
            &Curves.define_hermite/1
          ] do
        svg = Svg.render(define.(@b_spline), 50)
        assert length(line_points(svg)) == 51
      end
    end

    test "keeps everything inside the image" do
      svg =
        Svg.render(Curves.define_b_spline(@b_spline), 100, width: 300, height: 200, padding: 10)

      for {x, y} <- line_points(svg) do
        assert x >= 10.0 and x <= 290.0
        assert y >= 10.0 and y <= 190.0
      end
    end

    test "draws one dot per point, and no dots when turned off" do
      curve = Curves.define_catmull_rom(@b_spline)
      assert Svg.render(curve, 10) |> count("<circle") == 6
      assert Svg.render(curve, 10, show_points: false) |> count("<circle") == 0
    end

    test "dots follow the curve when it is moved" do
      curve =
        Curves.define_bezier([{0, 0}, {10, 10}]) |> Curves.Transform.set_position({100, 100})

      svg = Svg.render(curve, 2, width: 100, height: 100, padding: 0)
      assert svg =~ ~s(<circle cx="0.00" cy="100.00")
      assert svg =~ ~s(<circle cx="100.00" cy="0.00")
    end

    test "a flat curve doesn't divide by zero" do
      svg =
        Svg.render(Curves.define_bezier(:linear_horizontal), 2,
          width: 100,
          height: 100,
          padding: 0
        )

      assert line_points(svg) == [{0.0, 50.0}, {50.0, 50.0}, {100.0, 50.0}]
    end

    test "optional parts" do
      curve = Curves.define_bezier(:linear)
      refute Svg.render(curve, 2) =~ "stroke-dasharray"
      assert Svg.render(curve, 2, show_polygon: true) =~ "stroke-dasharray"
      refute Svg.render(curve, 2, background: nil) =~ "<rect"
      assert Svg.render(curve, 2, title: "a < b & \"c\"") =~ "a &lt; b &amp; &quot;c&quot;</text>"
    end

    test "passes solve_opts through" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])

      svg =
        Svg.render(curve, 2,
          solve_opts: [force_percent: true],
          show_points: false,
          width: 100,
          height: 100,
          padding: 0
        )

      assert line_points(svg) == [{0.0, 100.0}, {50.0, 50.0}, {100.0, 0.0}]
    end

    test "raises on a bad sample count" do
      assert_raise FunctionClauseError, fn -> Svg.render(Curves.define_bezier(:linear), 0) end
    end
  end

  # How many times `part` appears in `text`.
  @spec count(String.t(), String.t()) :: non_neg_integer()
  defp count(text, part), do: length(String.split(text, part)) - 1
end
