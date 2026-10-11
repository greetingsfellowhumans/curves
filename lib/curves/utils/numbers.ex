defmodule Curves.Utils.Numbers do
  @moduledoc false

  # Splits a float into its whole part and its fraction, e.g. 2.25 -> {2, 0.25} and -0.5 -> {0, -0.5}.
  # -0.0 becomes +0.0, so Segment.split_u/2's {0, +0.0} clause still matches it.
  @spec split_float(float()) :: {integer(), float()}
  def split_float(float) when is_float(float) and float == 0.0, do: {0, 0.0}

  # Below 1 the fraction is the float itself, which is exact and keeps its sign.
  def split_float(float) when is_float(float) and float > -1.0 and float < 1.0, do: {0, float}

  def split_float(float) when is_float(float) and float < 0.0 do
    {whole, fraction} = split_float(-float)
    {-whole, -fraction}
  end

  # From 1 up, the printed digits give the exact decimal fraction:
  # 2.1 gives 0.1, where 2.1 - 2 would give 0.10000000000000009.
  def split_float(float) when is_float(float) do
    str = Float.to_string(float) |> String.split(".") |> List.last()
    {t, _} = Float.parse("0." <> str)
    {trunc(float), t}
  end
end
