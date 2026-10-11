defmodule Curves.Polyline.CurveTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Transform

  @knots [{0, 0}, {2, 4}, {6, 4}, {7, -1}]

  describe "define_polyline/2" do
    test "passes through every knot at whole numbers of u" do
      curve = Curves.define_polyline(@knots)

      for {{x, y}, u} <- Enum.with_index(@knots) do
        assert Curves.solve!(curve, u) == {x * 1.0, y * 1.0}
      end
    end

    test "max_u is the number of straight lines" do
      assert Curves.max_u(Curves.define_polyline(@knots)) == 3.0
      assert Curves.max_u(Curves.define_polyline([{0, 0}, {1, 1}])) == 1.0
    end

    test "each line is travelled at a steady speed" do
      curve = Curves.define_polyline(@knots)
      assert Curves.solve!(curve, 0.5) == {1.0, 2.0}
      assert Curves.solve!(curve, 1.25) == {3.0, 4.0}
      assert Curves.solve!(curve, 2.5) == {6.5, 1.5}
    end

    test "a single knot is a single point" do
      curve = Curves.define_polyline([{3, 4}])
      assert Curves.max_u(curve) == 0.0
      assert Curves.solve!(curve, 0.0) == {3.0, 4.0}
      assert Curves.take!(curve, 3) == [{3.0, 4.0}, {3.0, 4.0}, {3.0, 4.0}]
    end

    test "bad input raises a clear ArgumentError" do
      assert_raise ArgumentError, "a polyline needs at least 1 point, got none", fn ->
        Curves.define_polyline([])
      end

      assert_raise ArgumentError, ~r/a polyline takes a list of \{x, y\} points/, fn ->
        Curves.define_polyline({0, 0})
      end

      assert_raise ArgumentError, ~r/expected an \{x, y\} point with numbers, got: :a/, fn ->
        Curves.define_polyline([{0, 0}, :a])
      end
    end
  end

  describe "solve/3 and take/3" do
    test "u outside 0..max_u is an error, or an OutOfBoundU exception" do
      curve = Curves.define_polyline(@knots)
      assert Curves.solve(curve, 3.5) == {:error, {:out_of_bounds, 3.5}}

      error = assert_raise Curves.Exceptions.OutOfBoundU, fn -> Curves.solve!(curve, 3.5) end
      assert error.max == 3.0 and error.u == 3.5
    end

    test "a u that isn't a number raises an ArgumentError" do
      assert_raise ArgumentError, "u must be a number, got: :x", fn ->
        Curves.solve(Curves.define_polyline(@knots), :x)
      end
    end

    test "take spreads n points over the whole polyline and ends on the last knot" do
      curve = Curves.define_polyline(@knots)

      assert Curves.take!(curve, 6) == [
               {1.0, 2.0},
               {2.0, 4.0},
               {4.0, 4.0},
               {6.0, 4.0},
               {6.5, 1.5},
               {7.0, -1.0}
             ]

      assert {:ok, points} = Curves.take(curve, 6)
      assert length(points) == 6
    end

    test "force_percent rescales to the knots' bounds" do
      curve = Curves.define_polyline(@knots)
      assert Curves.solve!(curve, 1.0, force_percent: true) == {2 / 7, 1.0}
    end
  end

  describe "transforms" do
    test "scale and rotate around the position, then move there" do
      curve =
        Curves.define_polyline([{0, 0}, {1, 0}])
        |> Transform.set_position({10, 10})
        |> Transform.set_scale(2)
        |> Transform.set_rotation(90)

      assert Curves.solve!(curve, 0.0) == {10.0, 10.0}
      {x, y} = Curves.solve!(curve, 1.0)
      assert_in_delta x, 10.0, 1.0e-12
      assert_in_delta y, 12.0, 1.0e-12
    end

    test "the :origin option moves it" do
      curve = Curves.define_polyline([{0, 0}, {1, 1}], origin: {5, 5})
      assert Curves.solve!(curve, 1.0) == {6.0, 6.0}
    end
  end

  # a * (1 - t) + b * t isn't always exactly a when a == b; a flat line must stay exactly flat.
  test "equal coordinates stay exact, so flat lines and single points stay flat" do
    point = Curves.define_polyline([{0, 100}, {0, 100}]) |> Transform.set_scale(1000)
    assert Enum.uniq(Curves.take!(point, 50)) == [{0.0, 100_000.0}]

    flat = Curves.define_polyline([{0, 0.1}, {10, 0.1}])
    assert flat |> Curves.take!(50) |> Enum.map(&elem(&1, 1)) |> Enum.uniq() == [0.1]
  end

  test "Svg draws the knots as dots and no dashed lines" do
    svg = Curves.Svg.render(Curves.define_polyline(@knots), show_axes: false)
    assert length(Regex.scan(~r/<circle/, svg)) == 4
    refute svg =~ "stroke-dasharray"
  end

  # Between knots k and k + 1, u = k + f is exactly f of the way along the straight line.
  property "is straight and steady between every pair of knots" do
    check all(
            knots <-
              StreamData.list_of(
                StreamData.tuple({StreamData.integer(-50..50), StreamData.integer(-50..50)}),
                min_length: 2,
                max_length: 8
              ),
            f <- StreamData.float(min: 0.0, max: 1.0)
          ) do
      curve = Curves.define_polyline(knots)

      for {[{ax, ay}, {bx, by}], k} <- Enum.with_index(Enum.chunk_every(knots, 2, 1, :discard)) do
        {x, y} = Curves.solve!(curve, k + f)
        assert_in_delta x, ax + f * (bx - ax), 1.0e-9
        assert_in_delta y, ay + f * (by - ay), 1.0e-9
      end
    end
  end
end
