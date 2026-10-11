defmodule Curves.Utils.Derivatives do
  @moduledoc false
  # Estimates slopes on a curve, and lets a spline type rebuild its segments from them.
  alias Curves.Types, as: T
  @small_num Curves.Utils.Constants.small_number()

  # The slope at `t`, as `{rise, run}`, estimated from a second point a small step before `t`.
  # A vertical slope gives `{1_000_000, 1}`.
  @spec get_derivative(T.curve_struct(), number(), :tuple) :: {number(), number()}
  def get_derivative(curve, t, :tuple) do
    coord =
      case t do
        0 -> 0.0
        _ -> t - @small_num
      end

    {x0, y0} = Curves.solve!(curve, t)
    {x1, y1} = Curves.solve!(curve, coord)

    case {y1 - y0, x1 - x0} do
      {_, +0.0} -> {1_000_000, 1}
      {y, x} -> {y, x}
    end
  end

  # Rebuilds each segment with the spline type's map_segments/2 (e.g. working out control points
  # from slopes). Bezier splines already have their control points, so they're left unchanged.
  @spec apply_derivatives(Curves.Spline.Curve.t()) :: Curves.Spline.Curve.t()
  def apply_derivatives(%Curves.Spline.Curve{type: :bezier_spline} = curve), do: curve

  def apply_derivatives(%Curves.Spline.Curve{segments: segments, mod: mod} = curve) do
    %{curve | segments: segments |> Enum.with_index() |> mod.map_segments(curve)}
  end
end
