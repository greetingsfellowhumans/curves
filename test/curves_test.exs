defmodule CurvesTest do
  use ExUnit.Case
  # doctest Curves
  #
  describe "Curves" do
    test "take/3" do
      curve = Curves.define_bezier(:ease_in)
      points = Curves.take!(curve, 3)
      assert Enum.count(points) == 3
      [{x, y} | _] = points
      assert is_float(x)
      assert is_float(y)
      {:ok, points_b} = Curves.take(curve, 3)
      assert points == points_b
    end
  end
end
