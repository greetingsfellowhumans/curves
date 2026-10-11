defmodule Curves.Transform.Scale do
  @moduledoc false
  alias Curves.Types, as: T

  # These only change the curve's :scale field. The points are scaled later, in compress.
  @spec set_scale(T.curve_data(), number()) :: T.curve_data()
  def set_scale(curve, scale) do
    transform(curve, fn _ -> scale end)
  end

  @spec inc_scale(T.curve_data(), number()) :: T.curve_data()
  def inc_scale(curve, amount) do
    transform(curve, fn scale -> scale + amount end)
  end

  @spec transform(T.curve_data(), (number() -> number())) :: T.curve_data()
  defp transform(curve, cb) do
    Map.update!(curve, :scale, cb)
  end
end
