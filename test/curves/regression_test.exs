defmodule Curves.RegressionTest do
  use ExUnit.Case

  @spline_points [{5, 10}, {10, 5}, {15, 10}, {20, 10}, {25, 5}, {30, 15}]

  describe "default precision" do
    test "defaults to f32" do
      curve = Curves.define_bezier([{0, 0}, {1000.123, 1}])
      assert Nx.type(curve.points) == {:f, 32}
      {x, _y} = Curves.solve!(curve, 0.5)
      assert_in_delta x, 500.0615, 0.001
    end

    test "float_dtype: 16 is still respected" do
      curve = Curves.define_bezier([{0, 0}, {1000.123, 1}], float_dtype: 16)
      assert Nx.type(curve.points) == {:f, 16}
    end
  end

  describe "spline u values" do
    test "accept integers" do
      curve = Curves.define_hermite(@spline_points)
      assert {:ok, {x, y}} = Curves.solve(curve, 1)
      assert {:ok, {^x, ^y}} = Curves.solve(curve, 1.0)
      assert Curves.solve!(curve, 1) == {x, y}
    end

    test "out of bounds returns the offending u, matching the bezier error shape" do
      curve = Curves.define_hermite(@spline_points)
      assert Curves.solve(curve, 99.0) == {:error, {:out_of_bounds, 99.0}}
      assert Curves.solve(curve, 99) == {:error, {:out_of_bounds, 99}}

      bezier = Curves.define_bezier(:linear)
      assert Curves.solve(bezier, 2.0) == {:error, {:out_of_bounds, 2.0}}
    end

    test "solve! raises OutOfBoundU" do
      curve = Curves.define_hermite(@spline_points)
      assert_raise Curves.Exceptions.OutOfBoundU, fn -> Curves.solve!(curve, 99) end
    end
  end

  describe "spline take/2" do
    # Float rounding used to push the final sample just past max_u, e.g. 3 * (3 / 187) * 187 > 3.0
    test "never overshoots the final segment" do
      known_overshoots = [{3, 187}, {3, 273}, {3, 275}]
      sweep = for segments <- 1..6, n <- 1..40, do: {segments, n}

      for {segments, n} <- known_overshoots ++ sweep do
        curve = Curves.define_catmull_rom(Enum.map(0..segments, &{&1, rem(&1, 2)}))
        assert {:ok, points} = Curves.take(curve, n), "#{segments} segments, n=#{n}"
        assert length(points) == n
      end
    end

    test "take! returns points" do
      curve = Curves.define_hermite(@spline_points)
      assert length(Curves.take!(curve, 7)) == 7
    end
  end

  describe "force_percent" do
    test "bezier honours it when passed to define" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}], force_percent: true)
      assert Curves.solve!(curve, 1.0) == {1.0, 1.0}
      assert Curves.solve!(curve, 0.0) == {0.0, 0.0}
    end

    test "bezier honours it when passed to solve" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])
      assert Curves.solve!(curve, 1.0, force_percent: true) == {1.0, 1.0}
      assert Curves.solve!(curve, 1.0) == {40.0, 400.0}
    end

    test "spline honours it when passed to solve" do
      curve = Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}])
      {x, y} = Curves.solve!(curve, curve.max_u)
      assert {x, y} == {30.0, 100.0}
      {px, py} = Curves.solve!(curve, curve.max_u, force_percent: true)
      assert_in_delta px, 1.0, 0.001
      assert_in_delta py, 1.0, 0.001
    end
  end

  describe "bezier point count" do
    test "more than 4 points returns an error instead of tensors" do
      curve = Curves.define_bezier([{0, 0}, {1, 1}, {2, 0}, {3, 1}, {4, 0}])
      assert Curves.solve(curve, 0.5) == {:error, {:too_many_points, 5, 4}}
      assert Curves.take(curve, 3) == {:error, {:too_many_points, 5, 4}}
      assert_raise Curves.Exceptions.TooManyPoints, fn -> Curves.solve!(curve, 0.5) end
      assert_raise Curves.Exceptions.TooManyPoints, fn -> Curves.take!(curve, 3) end
    end

    test "fewer than 2 points can be defined and transformed, but not solved" do
      curve = Curves.define_bezier([{0, 0}]) |> Curves.Transform.set_scale(2.0)
      assert Curves.solve(curve, 0.5) == {:error, {:too_few_points, 1, 2}}
      assert_raise Curves.Exceptions.TooFewPoints, fn -> Curves.solve!(curve, 0.5) end
    end
  end
end
