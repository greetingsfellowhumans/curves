defmodule Curves.Spline.BSplineTest do
  use ExUnit.Case
  alias Curves.Spline.Type.BSpline, as: Mod
  import Mod
  import Curves.Support.SampleCurves
  alias Curves.Utils.{Point, Points}

  setup [:with_curves]

  def initial_args(ctx, k \\ :b_spline) do
    curve_spec = ctx.curve_specs[k]
    curve_spec
  end

  describe "B-Splines" do

    test "split points", ctx do
      curve_spec = ctx.curve_specs[:b_spline]
      assert split_points({10, 10}, {14, 20}, 1) == [{12.0, 15.0}]
      assert split_points({0, 0}, {6, 9}, 2) == [{2.0, 3.0}, {4.0, 6.0}]
      assert split_points({0, 0}, {6, 9}, 1) == [{3.0, 4.5}]

      assert split_points({0, 0}, {3, 6}, 2) == [{1.0, 2.0}, {2.0, 4.0}]
      #assert split_points({3, 6}, {8, 6}, 2) == [{4.666, 6.0}, {4.666, 6.0}]
    end

    test "rebuild_points", ctx do
      curve_spec = ctx.curve_specs[:b_spline]
      points = rebuild_points(curve_spec, [])
      assert points == [
        [
          {3.3333333333333335, 5.0},
          {4.666666666666667, 6.0},
          {6.333333333333334, 6.0},
        ],
        [
          {7.833333333333334, 5.333333333333334},
          {9.333333333333334, 4.666666666666667},
          {10.666666666666666, 3.3333333333333335},
        ],
        [
          {12.333333333333332, 3.833333333333334},
          {14.0, 4.333333333333334},
          {16.0, 6.666666666666667}
        ]
      ]
      curve = define_b_spline(curve_spec, [])
      assert is_struct(curve, Curves.Spline.Curve)
    end

  end

end
