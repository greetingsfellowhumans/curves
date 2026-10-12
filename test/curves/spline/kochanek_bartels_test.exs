defmodule Curves.Spline.KochanekBartelsTest do
  use ExUnit.Case, async: true

  @knots [{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}]

  # Checks two points are equal to within float rounding.
  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  # The direction the curve travels just before and just after u.
  @spec directions(Curves.Spline.Curve.t(), float()) :: {{float(), float()}, {float(), float()}}
  defp directions(curve, u) do
    {bx, by} = Curves.solve!(curve, u - 1.0e-6)
    {x, y} = Curves.solve!(curve, u)
    {ax, ay} = Curves.solve!(curve, u + 1.0e-6)
    {normalise({x - bx, y - by}), normalise({ax - x, ay - y})}
  end

  @spec normalise({float(), float()}) :: {float(), float()}
  defp normalise({x, y}) do
    length = :math.sqrt(x * x + y * y)
    {x / length, y / length}
  end

  test "passes through every knot, with any dials" do
    curve = Curves.define_kochanek_bartels(@knots, tension: 0.3, continuity: 0.4, bias: -0.7)
    assert Curves.max_u(curve) == 4.0

    for {{x, y}, i} <- Enum.with_index(@knots),
        do: assert_near(Curves.solve!(curve, i * 1.0), {x * 1.0, y * 1.0})
  end

  test "with every dial at 0 it is Catmull-Rom" do
    catmull_rom = Curves.define_catmull_rom(@knots)
    curve = Curves.define_kochanek_bartels(@knots, tension: 0, continuity: 0, bias: 0)

    for u <- [0.0, 0.3, 1.5, 3.9, 4.0],
        do: assert_near(Curves.solve!(curve, u), Curves.solve!(catmull_rom, u))
  end

  test "continuity 0 keeps the direction smooth at each knot; other values make corners" do
    # Directions measured from points 1e-6 apart are only accurate to about 1e-5.
    {{bx, by}, {ax, ay}} = directions(Curves.define_kochanek_bartels(@knots, bias: 0.5), 2.0)
    assert abs(bx - ax) < 1.0e-4 and abs(by - ay) < 1.0e-4

    {{bx, _by}, {ax, _ay}} =
      directions(Curves.define_kochanek_bartels(@knots, continuity: -0.5), 2.0)

    assert abs(bx - ax) > 1.0e-2
  end

  test "continuity -1 is a polyline" do
    curve = Curves.define_kochanek_bartels(@knots, continuity: -1)
    polyline = Curves.define_polyline(@knots)

    for u <- [0.25, 1.5, 2.75, 3.1],
        do: assert_near(Curves.solve!(curve, u), Curves.solve!(polyline, u))
  end

  test "bias leans each knot's direction towards the line before it, or after it" do
    # At the knot {2, 3}, the line before rises (direction {2, 3}) and the line after falls ({2, -2}).
    {_, {_x, late}} = directions(Curves.define_kochanek_bartels(@knots, bias: 1), 1.0)
    {_, {_x, early}} = directions(Curves.define_kochanek_bartels(@knots, bias: -1), 1.0)
    # bias 1 follows the line before (still rising), bias -1 the line after (already falling).
    assert late > 0
    assert early < 0
  end

  test "stores the knots as its points" do
    curve = Curves.define_kochanek_bartels(@knots, bias: 0.5)
    assert curve.points == Enum.map(@knots, fn {x, y} -> {x * 1.0, y * 1.0} end)
    assert curve.type == :kochanek_bartels
  end

  test "one knot stays put" do
    assert Curves.take!(Curves.define_kochanek_bartels([{1, 2}], bias: 1), 2) == [
             {1.0, 2.0},
             {1.0, 2.0}
           ]
  end

  test "a dial that isn't a number raises an ArgumentError" do
    for key <- [:tension, :continuity, :bias] do
      assert_raise ArgumentError, "the #{inspect(key)} option must be a number, got: nil", fn ->
        Curves.define_kochanek_bartels(@knots, [{key, nil}])
      end
    end
  end
end
