defmodule Curves.Spline.HermiteSplineTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Transform

  @points [[{0, 0}, {4, 0}], [{2, 2}, {0, 4}], [{4, 0}, {4, 0}], [{7, 3}, {-2, 5}]]

  @spec assert_near({float(), float()}, {number(), number()}, float()) :: true
  defp assert_near({ax, ay}, {bx, by}, tolerance) do
    assert abs(ax - bx) <= tolerance and abs(ay - by) <= tolerance,
           "#{inspect({ax, ay})} is not within #{tolerance} of #{inspect({bx, by})}"
  end

  test "passes exactly through every knot" do
    curve = Curves.define_hermite(@points)
    assert Curves.max_u(curve) == 3.0

    for {[knot, _tangent], u} <- Enum.with_index(@points) do
      assert_near(Curves.solve!(curve, u * 1.0), knot, 1.0e-12)
    end
  end

  test "leaves each knot along its tangent" do
    curve = Curves.define_hermite(@points)
    h = 1.0e-6

    for {[_knot, {tx, ty}], u} <- Enum.with_index(@points), u < 3 do
      {x0, y0} = Curves.solve!(curve, u * 1.0)
      {x1, y1} = Curves.solve!(curve, u + h)
      assert_near({(x1 - x0) / h, (y1 - y0) / h}, {tx, ty}, 1.0e-4)
    end
  end

  test "the middle of a segment is (p0 + p1) / 2 + (m0 - m1) / 8" do
    curve = Curves.define_hermite([[{0, 0}, {4, 0}], [{2, 2}, {0, 4}]])
    assert Curves.solve!(curve, 0.5) == {1.5, 0.5}
  end

  test "moving the curve moves every point by the same amount" do
    curve = Curves.define_hermite(@points)
    moved = Transform.set_position(curve, {100, 100})

    for u <- [0.0, 0.3, 1.5, 2.9, 3.0] do
      {x, y} = Curves.solve!(curve, u)
      assert_near(Curves.solve!(moved, u), {x + 100, y + 100}, 1.0e-9)
    end
  end

  test "rejects points that aren't [knot, tangent]" do
    assert_raise ArgumentError, ~r/must be \[\{x, y\}, \{tangent_x, tangent_y\}\]/, fn ->
      Curves.define_hermite([{0, 0}, {1, 1}])
    end

    assert_raise ArgumentError, ~r/at least 2 points/, fn ->
      Curves.define_hermite([[{0, 0}, {1, 1}]])
    end
  end

  property "always passes through its knots" do
    point =
      StreamData.tuple(
        {StreamData.float(min: -50.0, max: 50.0), StreamData.float(min: -50.0, max: 50.0)}
      )

    check all(
            points <-
              StreamData.list_of(StreamData.fixed_list([point, point]),
                min_length: 2,
                max_length: 8
              )
          ) do
      curve = Curves.define_hermite(points)

      for {[knot, _], u} <- Enum.with_index(points) do
        assert_near(Curves.solve!(curve, u * 1.0), knot, 1.0e-9)
      end
    end
  end
end
