defmodule Curves.Spline.EllipseTest do
  use ExUnit.Case, async: true
  alias Curves.Transform

  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  test "a whole ellipse: one segment, starting and ending exactly on the right of its x axis" do
    curve = Curves.define_ellipse({1, 2}, {4, 2})
    assert Curves.max_u(curve) == 1.0
    assert Curves.solve!(curve, 0.0) == {5.0, 2.0}
    assert Curves.solve!(curve, 1.0) == {5.0, 2.0}
    assert_near(Curves.solve!(curve, 0.25), {1.0, 4.0})
    assert_near(Curves.solve!(curve, 0.5), {-3.0, 2.0})
    assert_near(Curves.solve!(curve, 0.75), {1.0, 0.0})
  end

  test "a circle moves at a steady speed" do
    curve = Curves.define_circle({0, 0}, 3)

    for t <- [0.1, 0.37, 0.8] do
      {x, y} = Curves.solve!(curve, t)

      assert_in_delta :math.atan2(y, x),
                      t * 2 * :math.pi() - if(t > 0.5, do: 2 * :math.pi(), else: 0),
                      1.0e-9

      assert_in_delta x * x + y * y, 9.0, 1.0e-9
    end
  end

  test ":from and :to make an arc; :to smaller goes the other way" do
    up = Curves.define_circle({0, 0}, 1, from: 0, to: 90)
    assert_near(Curves.solve!(up, 1.0), {0.0, 1.0})
    down = Curves.define_circle({0, 0}, 1, from: 0, to: -90)
    assert_near(Curves.solve!(down, 1.0), {0.0, -1.0})
    twice = Curves.define_circle({0, 0}, 1, to: 720)
    assert_near(Curves.solve!(twice, 0.5), {1.0, 0.0})
  end

  test ":rotation tilts the ellipse around its centre" do
    curve = Curves.define_ellipse({1, 1}, {4, 2}, rotation: 90)
    assert_near(Curves.solve!(curve, 0.0), {1.0, 5.0})
    assert_near(Curves.solve!(curve, 0.25), {-1.0, 1.0})
  end

  test "stores the box around it, so around: :center is its centre" do
    curve = Curves.define_ellipse({3, 1}, {4, 2})
    turned = Transform.set_rotation(curve, 90, around: :center)
    # The right end of the x axis, {7, 1}, turns to the top: {3, 5}.
    assert_near(Curves.solve!(turned, 0.0), {3.0, 5.0})
  end

  test ":force_percent covers the whole ellipse, even rotated" do
    curve = Curves.define_ellipse({0, 0}, {4, 2}, rotation: 30)

    for i <- 0..100 do
      {x, y} = Curves.solve!(curve, i / 100, force_percent: true)
      assert x >= 0.0 and x <= 1.0 and y >= 0.0 and y <= 1.0
    end
  end

  test "zero radii are allowed: a line back and forth, or a point" do
    flat = Curves.define_ellipse({0, 0}, {2, 0})
    assert_near(Curves.solve!(flat, 0.5), {-2.0, 0.0})
    point = Curves.define_circle({1, 1}, 0)
    assert Curves.take!(point, 2) == [{1.0, 1.0}, {1.0, 1.0}]
  end

  test "works with transforms and reverse" do
    curve = Curves.define_circle({0, 0}, 1, from: 0, to: 90, origin: {10, 0})
    assert_near(Curves.solve!(curve, 0.0), {11.0, 0.0})
    assert_near(Curves.solve!(Transform.reverse(curve), 0.0), {10.0, 1.0})
    assert_near(Curves.solve!(Transform.set_scale(curve, {2, 3}), 1.0), {10.0, 3.0})
  end

  test "bad input raises an ArgumentError" do
    assert_raise ArgumentError, ~r/the radii of an ellipse must be \{rx, ry\}/, fn ->
      Curves.define_ellipse({0, 0}, 5)
    end

    assert_raise ArgumentError,
                 ~r/the radius of a circle must be a number that is 0 or more/,
                 fn ->
                   Curves.define_circle({0, 0}, -1)
                 end

    assert_raise ArgumentError, "the :to option must be a number, got: :end", fn ->
      Curves.define_circle({0, 0}, 1, to: :end)
    end

    assert_raise ArgumentError, ~r/expected an \{x, y\} point/, fn ->
      Curves.define_circle(:middle, 1)
    end
  end
end
