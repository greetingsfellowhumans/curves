defmodule Curves.Spline.BezierSplineTest do
  use ExUnit.Case
  alias Curves.Utils.{Points, Point}
  alias Curves.Formula.{BezierSpline, CubicBezier}


  @curve0 [
    # P0
    [{5.0, 10.0},
      {10.0, 10.0}
    ],

    # P1
    [
     {10.0, 5.0},
     {5.0, 5.0},
    ],
  ]

  @curve1 [
    # P0
    [{5.0, 10.0},
      {10.0, 10.0}
    ],

    # P1
    [{10.0, 5.0},
     {5.0, 5.0},
     {15.0, 5.0}],

    # P2
    [{15.0, 10.0},
     {15.0, 6.0},
     {15.0, 14.0 }],

    # P3
    [{20.0, 15.0},
     {16.0, 15.0},
     {23.0, 15.0}],

    # P4
    [{25.0, 10.0},
     {20.0, 10.0}]
  ]
  @curve0_knot0 Point.new_point({5.0, 10.0})
  @curve0_knot1 Point.new_point({10.0, 5.0})

  @curve1_knot0 Point.new_point({5.0, 10.0})
  @curve1_knot1 Point.new_point({10.0, 5.0})
  @curve1_knot2 Point.new_point({15.0, 10.0})
  @curve1_knot3 Point.new_point({20.0, 15.0})
  @curve1_knot4 Point.new_point({25.0, 10.0})

  test "should calculate a b_spline" do
    curve = Curves.define_spline(@curve1, :bezier_spline)
    p = Curves.solve_spline!(curve, 1.11, force_percent: false)
    dbg p
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
