defmodule Curves.Spline.BSplineTest do
  use ExUnit.Case
  alias Curves.Spline.Type.BSpline, as: Mod
  import Mod
  import Curves.Support.SampleCurves

  setup [:with_curves]

  def initial_args(ctx, k \\ :b_spline) do
    curve_spec = ctx.curve_specs[k]
    curve_spec
  end

  describe "B-Splines" do
    test "split points", _ctx do
      # curve_spec = ctx.curve_specs[:b_spline]
      assert split_points({10, 10}, {14, 20}, 1) == [{12.0, 15.0}]
      assert split_points({0, 0}, {6, 9}, 2) == [{2.0, 3.0}, {4.0, 6.0}]
      assert split_points({0, 0}, {6, 9}, 1) == [{3.0, 4.5}]

      assert split_points({0, 0}, {3, 6}, 2) == [{1.0, 2.0}, {2.0, 4.0}]
      # assert split_points({3, 6}, {8, 6}, 2) == [{4.666, 6.0}, {4.666, 6.0}]
    end

    test "rebuild_points", ctx do
      curve_spec = ctx.curve_specs[:b_spline]
      points = rebuild_points(curve_spec, [])

      assert points == [
               [
                 {3.3333333333333335, 5.0},
                 {4.666666666666667, 6.0},
                 {6.333333333333334, 6.0}
               ],
               [
                 {7.833333333333334, 5.333333333333334},
                 {9.333333333333334, 4.666666666666667},
                 {10.666666666666666, 3.3333333333333335}
               ],
               [
                 {12.333333333333332, 3.833333333333334},
                 {14.0, 4.333333333333334},
                 {16.0, 6.666666666666667}
               ]
             ]

      curve = define(curve_spec, [])
      assert is_struct(curve, Curves.Spline.Curve)
    end

    test "segments are solved in curve order", ctx do
      curve_spec = ctx.curve_specs[:b_spline]
      curve = define(curve_spec, [])
      [[first_start | _] | _] = rebuild_points(curve_spec, [])

      # u = 0 is the start of the first rebuilt segment, not the last one.
      {x, y} = Curves.solve!(curve, 0.0)
      assert_in_delta x, elem(first_start, 0), 0.0001
      assert_in_delta y, elem(first_start, 1), 0.0001

      # Each segment ends where the next one begins, so there are no jumps between them.
      for u <- 1..(trunc(curve.max_u) - 1) do
        {x0, y0} = Curves.solve!(curve, u - 0.000001)
        {x1, y1} = Curves.solve!(curve, u + 0.000001)
        assert_in_delta x0, x1, 0.001
        assert_in_delta y0, y1, 0.001
      end
    end
  end
end
