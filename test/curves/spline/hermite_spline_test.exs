defmodule Curves.Spline.HermiteSplineTest do
  use ExUnit.Case
  import Curves.Support.SampleCurves

  setup [:with_curves]


  describe "Hermite Splines" do
    test "Should build a hermite spline", ctx do
      curve = ctx.curve_specs.hermite0
        |> Curves.define_spline(:hermite)

      assert is_struct(curve, Curves.Spline.Curve)

      curve = ctx.curve_specs.hermite_flattened
        |> Curves.define_hermite()

      assert is_struct(curve, Curves.Spline.Curve)
    end
  end

end
