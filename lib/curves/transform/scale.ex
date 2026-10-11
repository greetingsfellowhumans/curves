defmodule Curves.Transform.Scale do
  @moduledoc false
  alias Curves.Transform.Pivot
  alias Curves.Types, as: T

  # A scale is a number (the same both ways) or an {x, y} pair (x and y scaled separately).
  @type scale() :: number() | {number(), number()}

  # These only change the curve's :scale field (and, with a pivot, its :origin).
  # The points are scaled later, in compress.
  @spec set_scale(T.curve_data(), scale(), Pivot.around()) :: T.curve_data()
  def set_scale(curve, scale, around \\ nil) do
    transform(curve, around, fn _ -> scale end)
  end

  @spec inc_scale(T.curve_data(), scale(), Pivot.around()) :: T.curve_data()
  def inc_scale(curve, amount, around \\ nil) do
    transform(curve, around, &add(&1, amount))
  end

  # Mirrors the curve by turning the x (or y) scale negative, or back again.
  @spec flip(T.curve_data(), :x | :y, Pivot.around()) :: T.curve_data()
  def flip(curve, axis, around \\ nil) do
    transform(curve, around, &negate(&1, axis))
  end

  @spec transform(T.curve_data(), Pivot.around(), (scale() -> scale())) :: T.curve_data()
  defp transform(curve, around, cb) do
    Pivot.keep_in_place(curve, around, &Map.update!(&1, :scale, cb))
  end

  # Adds to the scale; a number adds to both x and y.
  @spec add(scale(), scale()) :: scale()
  defp add({x, y}, {dx, dy}), do: {x + dx, y + dy}
  defp add({x, y}, d), do: {x + d, y + d}
  defp add(s, {dx, dy}), do: {s + dx, s + dy}
  defp add(s, d), do: s + d

  @spec negate(scale(), :x | :y) :: {number(), number()}
  defp negate({x, y}, :x), do: {-x, y}
  defp negate({x, y}, :y), do: {x, -y}
  defp negate(s, axis), do: negate({s, s}, axis)
end
