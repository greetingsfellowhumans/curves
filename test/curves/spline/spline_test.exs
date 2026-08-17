#defmodule Curves.Spline.SplineTest do
#  use ExUnit.Case
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
#end
