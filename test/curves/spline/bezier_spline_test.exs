defmodule Curves.Spline.BezierSplineTest do
  use ExUnit.Case
  import Curves.Support.SampleCurves

  setup [:with_curves]


  test "should calculate a bezier spline", ctx do
    curve = ctx.curves.curve1
    {x, y} = Curves.solve_spline!(curve, 1.11)
    assert is_float(x)
    assert is_float(y)

    curve = ctx.curves.curve0
    assert_raise Curves.Exceptions.OutOfBoundU, fn -> Curves.solve_spline!(curve, 1.11) end

    #tuples0 =
    #  @sample_points
    #  |> List.flatten()
    #  |> Enum.slice(0..3)

    #segment0 = Points.new_points(tuples0, float_dtype: 32)
    #t = 0.95
    #tpoint = Curves.Formula.run(BSpline, segment0, t, [])
    #dbg tpoint
    #tpoint = Curves.Formula.run(CubicBezier, segment0, t, [])
    #dbg tpoint
  end

#  alias Curves.Spline
#  alias Curves.Utils.{Points, Point}
#  import Point
#
#  @points [
#    # start
#    {0, 0},
#    {25, 25},
#    {50, 50},
#    # join
#    {75, 75},
#    {100, 100},
#    {125, 125},
#    # join
#    {150, 150},
#    {175, 175},
#    {200, 200},
#    # stop
#    {225, 225}
#  ]
#
#  # test "split_points/1" do
#  #    curve = Curves.define_bezier(@points)
#  #    [ hd, tl ] =  Spline.split_points(curve.points)
#  #    assert Nx.size(hd[dimension: 0]) == 4
#  #    assert Nx.size(tl[dimension: 0]) > 4
#
#  #    #assert hd == Points.new_points([{0,0}, {25, 25}, {50, 50}, {75, 75}])
#  #    #  assert tl == Points.new_points([{75, 75}, {100, 100}, {125, 125}, {150, 150}, {175, 175}, {200, 200}])
#
#  #  #p = Spline.join_curves([hd, tl], 1.0, [])
#  #  #  assert p == {150.0, 150.0}
#  #  end
#
#  #  test "solve" do
#  #    curve = Curves.define_spline(@points)
#  #    assert (75 / 2) == 37.5
#  #    {37.5, 37.5} = Spline.solve(curve, 0.5, [])
#  #    {112.5, 112.5} = Spline.solve(curve, 1.5, [])
#  #  end
end
