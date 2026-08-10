defmodule Curves.Bezier.CubicTest do
  use ExUnit.Case
  alias Curves.Bezier.Cubic, as: Mod
  alias Curves.Utils.Points
  import Mod
  doctest Mod

  test "Cubic Bezier" do
    points =
      Points.new_points(
        [
          {0, 0},
          {0, 0.5},
          {0.8, 0.4},
          {1, 1}
        ],
        float_dtype: 32
      )

    t = 0.5
    curve = get_cubic_point(points, t)
    p = Points.new_points([{0.425, 0.4625}], float_dtype: 32)
    assert curve == p
  end
end
