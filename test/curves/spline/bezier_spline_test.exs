defmodule Curves.Spline.BezierSplineTest do
  use ExUnit.Case
  import Curves.Support.SampleCurves

  setup [:with_curves]

  test "a plain list of {x, y} points raises a clear ArgumentError" do
    error =
      assert_raise ArgumentError, fn ->
        Curves.define_bezier_spline([{0, 0}, {1, 1}, {2, 0}])
      end

    assert error.message =~
             "[knot], [knot, control_point] or [knot, control_point0, control_point1]"

    assert error.message =~ "Got: {0, 0}"
  end

  test "a point with more than 3 tuples raises a clear ArgumentError" do
    assert_raise ArgumentError, ~r/list of 1 to 3/, fn ->
      Curves.define_bezier_spline([[{0, 0}, {1, 1}, {2, 2}, {3, 3}], [{4, 4}]])
    end
  end

  test "should calculate a bezier spline", ctx do
    curve = ctx.curves.curve1
    {x, y} = Curves.solve!(curve, 1.11)
    assert is_float(x)
    assert is_float(y)

    curve = ctx.curves.curve0
    assert_raise Curves.Exceptions.OutOfBoundU, fn -> Curves.solve!(curve, 1.11) end
  end

  describe "points work like SVG path commands" do
    # Each spline segment should be the same curve as the matching define_bezier.
    @spec assert_same_curve(Curves.Spline.Curve.t(), Curves.Bezier.Curve.t()) :: :ok
    defp assert_same_curve(spline, bezier) do
      for i <- 0..20 do
        {sx, sy} = Curves.solve!(spline, i / 20)
        {bx, by} = Curves.solve!(bezier, i / 20)
        assert abs(sx - bx) < 1.0e-12 and abs(sy - by) < 1.0e-12, "t = #{i / 20}"
      end

      :ok
    end

    test "[knot] is a straight line to the next knot (L)" do
      spline = Curves.define_bezier_spline([[{0, 0}], [{3, 6}]])
      assert_same_curve(spline, Curves.define_bezier([{0, 0}, {3, 6}]))
      # At a steady speed: halfway along u is halfway along the line.
      assert Curves.solve!(spline, 0.5) == {1.5, 3.0}
    end

    test "[knot, c] is a quadratic curve to the next knot (Q)" do
      spline = Curves.define_bezier_spline([[{0, 0}, {3, 6}], [{6, 0}]])
      assert_same_curve(spline, Curves.define_bezier([{0, 0}, {3, 6}, {6, 0}]))
    end

    test "[knot, c0, c1] is a cubic curve to the next knot (C)" do
      spline = Curves.define_bezier_spline([[{0, 0}, {1, 3}, {2, -1}], [{3, 1}]])
      assert_same_curve(spline, Curves.define_bezier([{0, 0}, {1, 3}, {2, -1}, {3, 1}]))
    end

    test "the last point can't have control points" do
      assert_raise ArgumentError, ~r/must be \[knot\], got: \[\{3, 1\}, \{4, 4\}\]/, fn ->
        Curves.define_bezier_spline([[{0, 0}, {1, 3}], [{3, 1}, {4, 4}]])
      end
    end
  end

  # The conversion function in guides/upgrading.md, section 10.
  @spec to_svg_style(list(list(tuple()))) :: list(list(tuple()))
  defp to_svg_style(points) do
    points
    |> Enum.chunk_every(2, 1)
    |> Enum.map(fn
      [[knot | _] = point, next] -> [knot, leaving(point), arriving(next)]
      [[knot | _]] -> [knot]
    end)
  end

  @spec leaving(list(tuple())) :: tuple()
  defp leaving([knot]), do: knot
  defp leaving([_knot, c]), do: c
  defp leaving([_knot, _arrive, leave]), do: leave

  @spec arriving(list(tuple())) :: tuple()
  defp arriving([knot]), do: knot
  defp arriving([_knot, c]), do: c
  defp arriving([_knot, arrive, _leave]), do: arrive

  # The converted points are the ones the reference results use, and those still match the
  # results recorded from the old points (test/curves/reference_results_test.exs).
  test "the upgrade guide's conversion turns rc.1 points into the rc.2 points" do
    old = [
      [{5.0, 10.0}, {10.0, 10.0}],
      [{10.0, 5.0}, {5.0, 5.0}, {15.0, 5.0}],
      [{15.0, 10.0}, {15.0, 6.0}, {15.0, 14.0}],
      [{20.0, 15.0}, {18.0, 15.0}, {23.0, 15.0}],
      [{30.0, 10.0}, {32.0, 5.0}]
    ]

    assert to_svg_style(old) == [
             [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],
             [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}],
             [{15.0, 10.0}, {15.0, 14.0}, {18.0, 15.0}],
             [{20.0, 15.0}, {23.0, 15.0}, {32.0, 5.0}],
             [{30.0, 10.0}]
           ]

    assert to_svg_style([[{1, 2}, {3, 4}]]) == [[{1, 2}]]
  end

  test "the upgrade guide's rc.1 and rc.2 examples are the same curve" do
    old_meaning =
      to_svg_style([
        [{5.0, 10.0}, {10.0, 10.0}],
        [{10.0, 5.0}, {5.0, 5.0}, {15.0, 5.0}],
        [{30.0, 10.0}, {32.0, 5.0}]
      ])

    assert old_meaning == [
             [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],
             [{10.0, 5.0}, {15.0, 5.0}, {32.0, 5.0}],
             [{30.0, 10.0}]
           ]
  end
end
