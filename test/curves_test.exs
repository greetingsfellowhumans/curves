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
    test "force percent" do
      curve = Curves.define_bezier([{10, 100}, {20, 200}, {30, 300}, {40, 400}])
      points = Curves.take!(curve, 4)
      [{17.5, 175.0} | _] = points
      points = Curves.take!(curve, 4, force_percent: true)
      [{0.25, 0.25}, {0.5, 0.5}, {0.75, 0.75}, {1.0, 1.0}] = points
    end
  end
end
