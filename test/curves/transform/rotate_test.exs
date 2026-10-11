defmodule Curves.Transform.RotateTest do
  use ExUnit.Case
  alias Curves.Transform
  alias Curves.Transform.Rotate
  alias Curves.Utils.Vec
  # doctest Transform
  import Curves.Support.SampleCurves

  setup [:with_curves]

  test "should calculate radians" do
    r =
      Curves.Transform.Rotate.degrees_to_radians(90)
      |> Float.round(5)

    assert r == 1.5708

    r =
      Curves.Transform.Rotate.degrees_to_radians(-45)
      |> Float.round(5)

    assert r == -0.7854
  end

  test "should rotate a point" do
    origin = {0.0, 0.0}
    {x, y} = Vec.rotate({1.0, 1.0}, Rotate.degrees_to_radians(90), origin)
    assert {Float.round(x, 5), Float.round(y, 5)} == {-1.0, 1.0}

    {x, y} = Vec.rotate({1.0, 1.0}, Rotate.degrees_to_radians(180), origin)
    assert {Float.round(x, 5), Float.round(y, 5)} == {-1.0, -1.0}

    {x, y} = Vec.rotate({1.0, 1.0}, Rotate.degrees_to_radians(-45), origin)
    assert Float.round(x, 5) > 1.0
    assert Float.round(y, 5) == 0.0
  end

  test "should rotate a list of points" do
    rad = Rotate.degrees_to_radians(90)

    rotated =
      for p <- [{1.0, 1.0}, {0.5, 0.5}, {-0.5, 0.25}] do
        {x, y} = Vec.rotate(p, rad, {0.0, 0.0})
        {Float.round(x, 5), Float.round(y, 5)}
      end

    assert rotated == [{-1.0, 1.0}, {-0.5, 0.5}, {-0.25, -0.5}]
  end

  test "should rotate a bezier curve", _ctx do
    curve = Curves.define_bezier(:linear_up_right)
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 0.0
    assert y == 0.0
    {x, y} = Curves.solve!(curve, 1.0)
    assert x == 1.0
    assert y == 1.0

    curve = Transform.set_rotation(curve, 90)
    {x, y} = Curves.solve!(curve, 1.0)
    assert Float.round(x, 1) == -1.0
    assert Float.round(y, 1) == 1.0
  end

  test "should rotate around a fixed point", _ctx do
    curve = Curves.define_bezier(:linear_up_right, origin: {10, 10})
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 10.0
    assert y == 10.0

    {x, y} = Curves.solve!(curve, 1.0)
    assert x == 11.0
    assert y == 11.0

    curve = Transform.set_rotation(curve, 90)
    {x, y} = Curves.solve!(curve, 1.0)
    assert Float.round(x, 1) == 9.0
    assert Float.round(y, 1) == 11.0
  end

  test "should rotate a bezier spline", ctx do
    curve = ctx.curves.curve1
    {x, y} = Curves.solve!(curve, 0.0)
    assert x == 5.0
    assert y == 10.0

    {x, y} = Curves.solve!(curve, 1.0)
    assert x == 10.0
    assert y == 5.0

    curve = Transform.set_rotation(curve, 90)
    {x, y} = Curves.solve!(curve, 0.0)
    assert Float.round(x, 1) == -10.0
    assert Float.round(y, 1) == 5.0

    curve = Transform.set_rotation(curve, 90)
    {x, y} = Curves.solve!(curve, 1.0)
    assert Float.round(x, 1) == -5.0
    assert Float.round(y, 1) == 10.0
  end
end
