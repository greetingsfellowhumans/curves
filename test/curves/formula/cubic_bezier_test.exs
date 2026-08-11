defmodule Curves.Formula.CubicBezierTest do
  use ExUnit.Case
  alias Curves.Formula, as: F
  alias F.CubicBezier, as: Mod
  #alias Curves.Bezier.{Cubic}
  #import Mod
  # doctest Mod
  @points [
    {0, 0},
    {25, 25},
    {50, 50},
    {75, 75},
    {100, 100},
    {125, 125},
    {150, 150},
    {175, 175},
    {200, 200},
  ]

  def repeat(cb, count) do
    for n <- 1..count do
      cb.(n)
    end
  end

  describe "Opts" do
    @tag skip: true
    test "get the correct options" do
      curve = Curves.define_curve(@points)
      t = 0.5
      regular = Curves.solve!(curve, t)
      assert regular == {27.5, 46.25}

      b = Curves.Formula.run(Mod, curve.points, t, [])
      m = Curves.Utils.Point.to_tuple(b)
      assert m == regular
    end


  end
end

