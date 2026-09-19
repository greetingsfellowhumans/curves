defmodule Curves.Utils.DerivativesTest do
  use ExUnit.Case
  use ExUnitProperties
  import Curves.Support.SampleCurves
  import Curves.Utils.{Derivatives, Point}

  setup [:with_curves]


  describe "Utils.Derivatives" do
    property "get_derivative/3", ctx do
      c = ctx.curves.curve1
      check all t <- StreamData.float(min: 0.0, max: 4.0) do
        d = get_derivative(c, t, :point)
        assert is_point(d)
      end
    end
    test "get_power_series/3" do
      assert get_power_series(0.5, 0, :asc) == Nx.tensor([1, 0.5, 0.25, 0.125])
      assert get_power_series(0.5, 0, :desc) == Nx.tensor([0.125, 0.25, 0.5, 1])
    end

    test "apply_derivatives", ctx do
      curve_spec = ctx.curve_specs.hermite_flattened
      curve = Curves.define_hermite(curve_spec)
      assert is_struct(curve, Curves.Spline.Curve)

    end
  end
end
