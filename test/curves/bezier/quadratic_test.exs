defmodule Curves.Bezier.QuadraticTest do
  use ExUnit.Case
  alias Curves.Bezier.Quadratic, as: Mod
  alias Curves.Utils.{Points}
  #import Point
  import Mod
  # doctest Mod

  test "Quadratic interpolation" do
    points =
      Points.new_points([
        {10, 10},
        {20, 40},
        {30, 60}
      ])

    t = 0.5
    p3 = get_quadratic_point(points, t)

    assert Nx.to_number(p3[1][0]) == 37.5

    # p0 = Points.point_at(points, 0)
    # p1 = Points.point_at(points, 1)
    # p2 = Points.point_at(points, 2)
    # assert get_quadratic_bezier_curve(p0, p1, p2, t) == expected_p3

    # t = 0.25
    # expected_p2 = Nx.tensor([4.0625, 2.875])
    # assert get_quadratic_bezier_curve(p0, pc, p1, t) == expected_p2
  end
end
