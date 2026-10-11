defmodule Curves.Transform.Rotate do
  @moduledoc false
  alias Curves.Types, as: T

  # Set (or add to, below) the curve's rotation field, in radians. The points are rotated later, in compress.
  @spec set_rotation(T.curve_data(), number()) :: T.curve_data()
  def set_rotation(curve, deg) do
    transform(curve, fn _ -> degrees_to_radians(deg) end)
  end

  @spec inc_rotation(T.curve_data(), number()) :: T.curve_data()
  def inc_rotation(curve, amount) do
    transform(curve, fn old -> old + degrees_to_radians(amount) end)
  end

  @spec transform(T.curve_data(), (float() -> float())) :: T.curve_data()
  defp transform(curve, cb) do
    Map.update!(curve, :rotation, cb)
  end

  @spec degrees_to_radians(number()) :: float()
  def degrees_to_radians(deg) do
    deg * :math.pi() / 180
  end
end
