defmodule CurvesTest do
  use ExUnit.Case
  doctest Curves

  describe "Curves" do
    test "max_u/1 of something that isn't a curve raises an ArgumentError" do
      assert_raise ArgumentError, ~r/expected a Curves.Bezier.Curve/, fn -> Curves.max_u(:x) end
    end

    test "every spline raises an ArgumentError for a bad :origin, or points that aren't a list" do
      for define <- [
            &Curves.define_catmull_rom/2,
            &Curves.define_cardinal/2,
            &Curves.define_centripetal_catmull_rom/2,
            &Curves.define_kochanek_bartels/2,
            &Curves.define_monotone/2,
            &Curves.define_natural_cubic/2,
            &Curves.define_b_spline/2
          ] do
        assert_raise ArgumentError, ~r/expected an \{x, y\} point/, fn ->
          define.([{0, 0}, {1, 1}, {2, 0}, {3, 1}], origin: [1, 2])
        end

        assert_raise ArgumentError, "a spline takes a list of points, got: {1, 2}", fn ->
          define.({1, 2}, [])
        end
      end

      for define <- [&Curves.define_hermite/2, &Curves.define_bezier_spline/2] do
        assert_raise ArgumentError, "a spline takes a list of points, got: {1, 2}", fn ->
          define.({1, 2}, [])
        end
      end
    end

    test "a u a little past the end of a spline or polyline, from rounding, is the end" do
      u = Enum.reduce(1..30, 0.0, fn _, sum -> sum + 0.1 end)
      assert u > 3.0

      for curve <- [
            Curves.define_catmull_rom([{0, 0}, {1, 1}, {2, 0}, {3, 3}]),
            Curves.define_polyline([{0, 0}, {1, 1}, {2, 0}, {3, 3}])
          ] do
        assert Curves.solve(curve, u) == Curves.solve(curve, 3.0)
        assert Curves.solve(curve, 3.002) == {:error, {:out_of_bounds, 3.002}}
      end
    end

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
