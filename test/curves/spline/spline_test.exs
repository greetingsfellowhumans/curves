defmodule Curves.Spline.SplineTest do
  use ExUnit.Case
  alias Curves.Bezier.Cubic, as: Mod
  alias Curves.Utils.Points
  import Mod
  doctest Mod

  @points [
    {0, 0},
    {0.2, 0.8},
    {0.6, 0.3},
    {1, 1},
    {1.2, 1.3},
    {1.6, 1.8},
    {2, 2}
  ]


  test "Cubic Bezier" do
    curve = Curves.define_curve(@points)
    p = Curves.solve!(curve, 0.9)
    dbg p
  end
end
