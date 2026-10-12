defmodule Curves.Spline.NaturalCubicTest do
  use ExUnit.Case, async: true

  @knots [{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}]

  # Checks two points are equal to within float rounding.
  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  test "passes through every knot" do
    curve = Curves.define_natural_cubic(@knots)
    assert Curves.max_u(curve) == 4.0

    for {{x, y}, i} <- Enum.with_index(@knots),
        do: assert_near(Curves.solve!(curve, i * 1.0), {x * 1.0, y * 1.0})
  end

  test "matches a natural cubic spline worked out by hand" do
    # Three knots {0, 0}, {1, 1}, {2, 0}: the equations give tangents {1, 1.5}, {1, 0} and {1, -1.5}.
    curve = Curves.define_natural_cubic([{0, 0}, {1, 1}, {2, 0}])

    assert curve.segments
           |> hd()
           |> Enum.map(fn {x, y} -> {Float.round(x, 12), Float.round(y, 12)} end) ==
             [{0.0, 0.0}, {0.333333333333, 0.5}, {0.666666666667, 1.0}, {1.0, 1.0}]
  end

  test "points along a straight line, evenly spaced, give that line at a steady speed" do
    curve = Curves.define_natural_cubic([{0, 0}, {1, 2}, {2, 4}, {3, 6}])
    for u <- [0.25, 1.5, 2.9], do: assert_near(Curves.solve!(curve, u), {u, 2 * u})
  end

  test "moving one knot changes every segment" do
    moved = List.replace_at(@knots, 4, {8, 10})
    before = Curves.define_natural_cubic(@knots)
    after_ = Curves.define_natural_cubic(moved)
    refute Curves.solve!(before, 0.5) == Curves.solve!(after_, 0.5)
  end

  test "one knot stays put and two make a straight line" do
    assert Curves.take!(Curves.define_natural_cubic([{1, 2}]), 2) == [{1.0, 2.0}, {1.0, 2.0}]
    assert_near(Curves.solve!(Curves.define_natural_cubic([{0, 0}, {4, 2}]), 0.25), {1.0, 0.5})
  end

  test "handles many knots" do
    knots = for i <- 0..2000, do: {i, :math.sin(i / 10)}
    curve = Curves.define_natural_cubic(knots)
    assert Curves.max_u(curve) == 2000.0
    assert_near(Curves.solve!(curve, 1234.0), {1234.0, :math.sin(123.4)})
  end

  test "stores the knots as its points" do
    curve = Curves.define_natural_cubic(@knots)
    assert curve.points == Enum.map(@knots, fn {x, y} -> {x * 1.0, y * 1.0} end)
    assert curve.type == :natural_cubic
  end

  test "an empty list raises an ArgumentError" do
    assert_raise ArgumentError, "a spline needs at least 1 point, got none", fn ->
      Curves.define_natural_cubic([])
    end
  end
end
