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
end
