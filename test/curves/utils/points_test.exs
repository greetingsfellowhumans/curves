defmodule Curves.Utils.PointsTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Curves.Utils.Points, as: Mod
  import Mod
  import Curves.Utils.Point
  doctest Mod

  describe "Points" do
    test "series of points" do
      opts = []

      coords = [
        {1, 10},
        {2, 20},
        {3, 30},
        {4, 40}
      ]

      p = new_points(coords, opts)
      assert is_points(p)
      assert Nx.type(p) == {:f, 16}
      assert Nx.shape(p) == {2, 4}

      el = tuple_at(p, 3)
      assert el == {4.0, 40.0}

      p2 = point_at(p, 2)
      assert is_point(p2)
      assert p2 == Curves.Utils.Point.new_point({3, 30}, opts)
    end

    test "A single point is equal to a series of points, of length 1" do
      p = new_points([{1, 2}], [])
      assert is_point(p)
      assert is_points(p)
    end

    test "Conversions" do
      coords = [
        {1, 10},
        {2, 20},
        {3, 30},
        {4, 40}
      ]

      points = new_points(coords, [])

      maps = to_maps(points)
      assert maps == [
        %{x: 1.0, y: 10.0},
        %{x: 2.0, y: 20.0},
        %{x: 3.0, y: 30.0},
        %{x: 4.0, y: 40.0},
      ]
    end

    test "get_slope" do
      point0 = Curves.Utils.Point.new_point({0, 0})
      point1 = Curves.Utils.Point.new_point({5, 10})
      expected = 10 / 5
      actual = get_slope(point0, point1)
      assert expected == actual
    end

    property "get_slope is always correct" do
      check all x0 <- integer(),
                x1 <- integer(),
                y0 <- integer(),
                y1 <- integer() do
        point0 = Curves.Utils.Point.new_point({x0, y0})
        point1 = Curves.Utils.Point.new_point({x1, y1})
        slope = get_slope(point0, point1)

        assert is_float(slope)
      end
    end

    test "update_point" do
      coords = [
        {1, 10},
        {2, 20},
        {3, 30},
        {4, 40}
      ]

      points = new_points(coords, [])
      points = update_point_at(points, 1, fn {x, y} ->
        {x * 10, y * 10}
      end)

      assert to_tuples(points) == [
        {1, 10},
        {20, 200},
        {3, 30},
        {4, 40}
      ]
    end
  end
end
