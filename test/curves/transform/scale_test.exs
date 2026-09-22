defmodule Curves.Transform.ScaleTest do
  use ExUnit.Case
  alias Curves.Transform
  doctest Transform
  import Curves.Support.SampleCurves

  setup [:with_curves]


  test "should scale a bezier spline", ctx do
    curve = ctx.curves.curve1
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 5.0
    assert y == 10.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 7.1875
    assert y == 9.21875

    curve = Transform.set_scale(curve, 2)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 10.0
    assert y == 20.0
  end

  test "should scale a bezier curve", _ctx do
    curve = Curves.define_bezier(:linear)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 0.0
    assert y == 0.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 0.25
    assert y == 0.25

    curve = Transform.set_scale(curve, 2.0)

    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 0.0
    assert y == 0.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 0.5
    assert y == 0.5
  end
end
