defmodule Curves.Bezier.LinearTest do
  use ExUnit.Case
  require Curves.Utils.Point
  alias Curves.Bezier.Linear, as: Mod
  alias Curves.Utils.{Point, Points}
  import Mod
  doctest Mod

  test "Linear interpolation" do
    opts = []

    coords = [
      {0, 0},
      {10, 10}
    ]

    p = Points.new_points(coords, opts)
    p0 = Points.point_at(p, 0)
    p1 = Points.point_at(p, 1)
    t = 0.5
    p2 = get_linear_interpolation_point(p0, p1, t)
    assert Point.is_point(p2)
    assert Point.get_x(p2) == 5.0
    assert Point.get_y(p2) == 5.0
  end
end
