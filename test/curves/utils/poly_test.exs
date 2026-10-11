defmodule Curves.Utils.PolyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Utils.Poly

  @cubic_bezier [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  @spec point() :: StreamData.t({float(), float()})
  defp point,
    do:
      StreamData.tuple(
        {StreamData.float(min: -100.0, max: 100.0), StreamData.float(min: -100.0, max: 100.0)}
      )

  test "a line from {0, 0} to {2, 4}" do
    coefficients = Poly.coefficients([[1, 0], [-1, 1]], [{0.0, 0.0}, {2.0, 4.0}])
    assert coefficients == {{0.0, 0.0}, {2.0, 4.0}}
    assert Poly.eval(coefficients, 0.25) == {0.5, 1.0}
  end

  test "factor scales every coefficient" do
    assert Poly.coefficients([[2, 0], [0, 2]], [{1.0, 1.0}, {3.0, 3.0}], 0.5) ==
             {{1.0, 1.0}, {3.0, 3.0}}
  end

  property "a cubic bezier matches its closed form" do
    check all(
            p0 <- point(),
            p1 <- point(),
            p2 <- point(),
            p3 <- point(),
            t <- StreamData.float(min: 0.0, max: 1.0)
          ) do
      {x, y} = Poly.eval(Poly.coefficients(@cubic_bezier, [p0, p1, p2, p3]), t)
      mt = 1.0 - t
      weights = [mt * mt * mt, 3 * mt * mt * t, 3 * mt * t * t, t * t * t]

      expected_x =
        weights
        |> Enum.zip([p0, p1, p2, p3])
        |> Enum.map(fn {w, {px, _}} -> w * px end)
        |> Enum.sum()

      expected_y =
        weights
        |> Enum.zip([p0, p1, p2, p3])
        |> Enum.map(fn {w, {_, py}} -> w * py end)
        |> Enum.sum()

      assert_in_delta x, expected_x, 1.0e-9
      assert_in_delta y, expected_y, 1.0e-9
    end
  end
end
