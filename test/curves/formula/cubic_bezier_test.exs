defmodule Curves.Formula.CubicBezierTest do
  use ExUnit.Case
  alias Curves.Formula, as: F
  alias F.CubicBezier, as: Mod
  # alias Curves.Bezier.{Cubic}
  # import Mod
  # doctest Mod
  # At t = 0.5 a cubic bezier is (p0 + 3 * p1 + 3 * p2 + p3) / 8, which gives {27.5, 46.25} here.
  @points [
    {0, 0},
    {10, 30},
    {30, 60},
    {100, 100}
  ]

  def repeat(cb, count) do
    for n <- 1..count do
      cb.(n)
    end
  end

  describe "Opts" do
    test "get the correct options" do
      curve = Curves.define_bezier(@points)
      t = 0.5
      regular = Curves.solve!(curve, t)
      assert regular == {27.5, 46.25}

      b = Curves.Formula.run(Mod, curve.points, t, [])
      m = Curves.Utils.Point.to_tuple(b)
      assert m == regular
    end
  end
end
