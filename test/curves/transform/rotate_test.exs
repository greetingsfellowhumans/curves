defmodule Curves.Transform.RotateTest do
  use ExUnit.Case
  alias Curves.Transform
  alias Curves.Utils.{Point, Points, Segment}
  alias Curves.Transform.Rotate
  doctest Transform
  import Curves.Support.SampleCurves

  setup [:with_curves]


  test "should calculate radians" do
    r = Curves.Transform.Rotate.degrees_to_radians(90)
        |> Float.round(5)
    assert r == 1.5708

    r = Curves.Transform.Rotate.degrees_to_radians(-45)
        |> Float.round(5)
    assert r == -0.7854
  end
  
  test "should rotate a point" do
    rad = Rotate.degrees_to_radians(90)
    p0 = Point.new_point({1.0, 1.0})
    {x, y} = Rotate.rotate_points(p0, rad) |> Point.to_tuple()
    assert {Float.round(x, 5), Float.round(y, 5)} == {-1.0, 1.0}

    rad = Rotate.degrees_to_radians(180)
    p0 = Point.new_point({1.0, 1.0})
    {x, y} = Rotate.rotate_points(p0, rad) |> Point.to_tuple()
    assert {Float.round(x, 5), Float.round(y, 5)} == {-1.0, -1.0}

    rad = Rotate.degrees_to_radians(-45)
    p0 = Point.new_point({1.0, 1.0})
    {x, y} = Rotate.rotate_points(p0, rad) |> Point.to_tuple()
    assert Float.round(x, 5) > 1.0
    assert Float.round(y, 5) == 0.0
  end
  test "should rotate a list of points" do
    rad = Rotate.degrees_to_radians(90)
    list = Points.new_points([ {1.0, 1.0}, {0.5, 0.5}, {-0.5, 0.25}])
    tuples = Rotate.rotate_points(list, rad) |> Points.to_tuples()
            |> Enum.map(fn {x, y} -> {Float.round(x, 5), Float.round(y, 5)} end)
    [{x0, y0}, {x1, y1}, {x2, y2}] = tuples
    assert x0 == -1.0
    assert y0 == 1.0

    assert x1 == -0.5
    assert y1 == 0.5

    assert x2 == -0.25
    assert y2 == -0.5
  end
  test "should rotate a segment of points", ctx do
    rad = Rotate.degrees_to_radians(90)
    segments = Segment.new_segments(ctx.curve_specs.curve1)
    {size, _, _} = Nx.shape(segments)
    li = for i <- 0..size - 1 do
      segments[i] |> Rotate.rotate_points(rad)
    end

    segments2 = Nx.stack(li) |> Nx.rename([:segment, :dimension, :point])
    assert Nx.shape(segments) == Nx.shape(segments2)
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
