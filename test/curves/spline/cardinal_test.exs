defmodule Curves.Spline.CardinalTest do
  use ExUnit.Case, async: true
  alias Curves.Transform

  @knots [{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}]

  # Checks two points are equal to within float rounding.
  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  test "passes through every knot, one segment per pair of knots" do
    curve = Curves.define_cardinal(@knots, tension: 0.5)
    assert Curves.max_u(curve) == 4.0

    for {{x, y}, i} <- Enum.with_index(@knots),
        do: assert_near(Curves.solve!(curve, i * 1.0), {x * 1.0, y * 1.0})
  end

  test "tension 0 (the default) is Catmull-Rom" do
    catmull_rom = Curves.define_catmull_rom(@knots)

    for u <- [0.0, 0.3, 1.5, 2.25, 3.9, 4.0] do
      assert_near(Curves.solve!(Curves.define_cardinal(@knots), u), Curves.solve!(catmull_rom, u))

      assert_near(
        Curves.solve!(Curves.define_cardinal(@knots, tension: 0), u),
        Curves.solve!(catmull_rom, u)
      )
    end
  end

  test "tension 1 gives straight lines that slow down at each knot" do
    curve = Curves.define_cardinal(@knots, tension: 1)
    # Halfway along each line, exactly.
    assert_near(Curves.solve!(curve, 0.5), {1.0, 1.5})
    assert_near(Curves.solve!(curve, 2.5), {5.0, 2.5})
    # But not at a steady speed: a quarter of u is less than a quarter of the way.
    {x, _y} = Curves.solve!(curve, 0.25)
    assert x < 0.5
  end

  test "higher tension keeps the curve closer to the straight lines" do
    # Halfway along the first line is {1.0, 1.5}.
    distance = fn tension ->
      {x, y} = Curves.solve!(Curves.define_cardinal(@knots, tension: tension), 0.5)
      :math.sqrt((x - 1.0) ** 2 + (y - 1.5) ** 2)
    end

    assert distance.(-0.5) > distance.(0.0)
    assert distance.(0.0) > distance.(0.5)
    assert distance.(0.5) > distance.(1.0)
  end

  test "one knot stays put and two knots make a straight line" do
    one = Curves.define_cardinal([{3, 4}])
    assert Curves.max_u(one) == 1.0
    assert Curves.take!(one, 3) == [{3.0, 4.0}, {3.0, 4.0}, {3.0, 4.0}]

    two = Curves.define_cardinal([{0, 0}, {4, 2}], tension: 0.0)
    assert_near(Curves.solve!(two, 0.25), {1.0, 0.5})
  end

  test "stores the knots as its points, for Curves.Svg and :force_percent" do
    curve = Curves.define_cardinal(@knots, tension: 0.5)
    assert curve.points == Enum.map(@knots, fn {x, y} -> {x * 1.0, y * 1.0} end)
    assert curve.type == :cardinal
  end

  test "works with :origin, transforms and reverse" do
    curve = Curves.define_cardinal(@knots, tension: 0.5, origin: {10, 20})
    assert_near(Curves.solve!(curve, 1.0), {12.0, 23.0})

    moved = Transform.inc_position(curve, {1, 1})
    assert_near(Curves.solve!(moved, 1.0), {13.0, 24.0})

    reversed = Transform.reverse(curve)
    assert_near(Curves.solve!(reversed, 0.7), Curves.solve!(curve, 3.3))
  end

  test "bad input raises an ArgumentError" do
    assert_raise ArgumentError, "the :tension option must be a number, got: \"0.5\"", fn ->
      Curves.define_cardinal(@knots, tension: "0.5")
    end

    assert_raise ArgumentError, "a spline needs at least 1 point, got none", fn ->
      Curves.define_cardinal([])
    end

    assert_raise ArgumentError, ~r/expected an {x, y} point with numbers/, fn ->
      Curves.define_cardinal([{0, 0}, :nope])
    end
  end
end
