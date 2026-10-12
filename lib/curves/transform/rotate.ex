defmodule Curves.Transform.Rotate do
  @moduledoc false
  alias Curves.Transform.Pivot
  alias Curves.Types, as: T

  # Set (or add to, below) the curve's rotation field, in radians (and, with a pivot, its :origin).
  # The points are rotated later, in compress.
  @spec set_rotation(T.curve_data(), number(), Pivot.around()) :: T.curve_data()
  def set_rotation(curve, deg, around) do
    transform(curve, around, fn _ -> degrees_to_radians(deg) end)
  end

  @spec inc_rotation(T.curve_data(), number(), Pivot.around()) :: T.curve_data()
  def inc_rotation(curve, amount, around) do
    transform(curve, around, fn old -> old + degrees_to_radians(amount) end)
  end

  @spec transform(T.curve_data(), Pivot.around(), (float() -> float())) :: T.curve_data()
  defp transform(curve, around, cb) do
    Pivot.keep_in_place(curve, around, &Map.update!(&1, :rotation, cb))
  end

  @spec degrees_to_radians(number()) :: float()
  def degrees_to_radians(deg) do
    deg * :math.pi() / 180
  end
end
