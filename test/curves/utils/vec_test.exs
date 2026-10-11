defmodule Curves.Utils.VecTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Utils.Vec

  @spec point() :: StreamData.t({float(), float()})
  defp point,
    do:
      StreamData.tuple(
        {StreamData.float(min: -1.0e3, max: 1.0e3), StreamData.float(min: -1.0e3, max: 1.0e3)}
      )

  test "new/1 turns integers into floats" do
    assert Vec.new({1, 2}) === {1.0, 2.0}
  end

  test "add/2, subtract/2 and scale/2" do
    assert Vec.add({1.0, 2.0}, {3.0, -1.0}) == {4.0, 1.0}
    assert Vec.subtract({1.0, 2.0}, {3.0, -1.0}) == {-2.0, 3.0}
    assert Vec.scale({1.0, -2.0}, 3.0) == {3.0, -6.0}
  end

  test "rotate/3 turns counter-clockwise around the origin" do
    {x, y} = Vec.rotate({1.0, 0.0}, :math.pi() / 2, {0.0, 0.0})
    assert_in_delta x, 0.0, 1.0e-12
    assert_in_delta y, 1.0, 1.0e-12

    {x, y} = Vec.rotate({2.0, 1.0}, :math.pi(), {1.0, 1.0})
    assert_in_delta x, 0.0, 1.0e-12
    assert_in_delta y, 1.0, 1.0e-12
  end

  test "bounds/1 finds the lowest and highest x and y" do
    assert Vec.bounds([{0, 5}, {10, 1}, {4, 3}]) == %{xmin: 0, xmax: 10, ymin: 1, ymax: 5}
  end

  property "rotate/3 keeps the distance from the origin" do
    check all(p <- point(), origin <- point(), radians <- StreamData.float(min: -10.0, max: 10.0)) do
      before = distance(Vec.subtract(p, origin))
      after_ = distance(Vec.subtract(Vec.rotate(p, radians, origin), origin))
      assert_in_delta after_, before, 1.0e-9 * max(1.0, before)
    end
  end

  property "subtract/2 undoes add/2" do
    check all(a <- point(), b <- point()) do
      {x, y} = Vec.subtract(Vec.add(a, b), b)
      assert_in_delta x, elem(a, 0), 1.0e-9
      assert_in_delta y, elem(a, 1), 1.0e-9
    end
  end

  @spec distance({float(), float()}) :: float()
  defp distance({x, y}), do: :math.sqrt(x * x + y * y)
end
