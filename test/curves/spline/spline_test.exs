defmodule Curves.Spline.SplineTest do
  use ExUnit.Case
  alias Curves.Spline
  alias Curves.Utils.Points

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

    test "split_points/1" do
      curve = Curves.define_curve(@points)
      [ hd, tl ] =  Spline.split_points(curve.points)
      assert hd == Points.new_points([{0,0}, {25, 25}, {50, 50}, {75, 75}])
      assert tl == Points.new_points([{75, 75}, {100, 100}, {125, 125}, {150, 150}, {175, 175}, {200, 200}])
    end


end
