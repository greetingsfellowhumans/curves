defmodule Curves.Transform.MoveTest do
  use ExUnit.Case
  alias Curves.Transform
  doctest Transform
  import Curves.Support.SampleCurves

  setup [:with_curves]


  test "should move a bezier spline", ctx do
    curve = ctx.curves.curve1
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 5.0
    assert y == 10.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 7.1875
    assert y == 9.21875

    curve = Transform.inc_x(curve, 10)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 15.0
    assert y == 10.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 17.1875
    assert y == 9.21875

    curve = Transform.inc_y(curve, 10)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 15.0
    assert y == 20.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 17.1875
    assert y == 19.21875

    curve = Transform.inc_position(curve, {-10, -10})
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 5.0
    assert y == 10.0

    curve = Transform.set_position(curve, {-10, -10})
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == -5.0
    assert y == 0.0
  end

  test "should move a bezier curve", _ctx do
    curve = Curves.define_bezier(:linear)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 0.0
    assert y == 0.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 0.25
    assert y == 0.25

    curve = Transform.inc_x(curve, 10)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 10.0
    assert y == 0.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 10.25
    assert y == 0.25

    curve = Transform.inc_y(curve, 10)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 10.0
    assert y == 10.0

    {x, y} = Curves.solve!(curve, 0.25)
    assert x == 10.25
    assert y == 10.25

    curve = Transform.inc_position(curve, {-10, -10})
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 0.0
    assert y == 0.0

    curve = Transform.set_position(curve, {-10, -10})
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == -10.0
    assert y == -10.0
  end
end
