defmodule Curves.Utils.PointsTest do
  use ExUnit.Case
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
  end
end
