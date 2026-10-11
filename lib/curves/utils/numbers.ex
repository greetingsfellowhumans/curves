defmodule Curves.Utils.Numbers do
  @moduledoc false

  # Splits a float into its whole part and its fraction, e.g. 2.25 -> {2, 0.25} and -0.5 -> {0, -0.5}.
  # -0.0 becomes +0.0, so Segment.split_u/1's {0, +0.0} clause still matches it.
  @spec split_float(float()) :: {integer(), float()}
  def split_float(float) when is_float(float) and float == 0.0, do: {0, 0.0}

  # The subtraction is exact: a float minus its whole part loses no precision. So 2.1 gives
  # 0.10000000000000009, the true fraction of the float 2.1 (which is really 2.100000000000000088...).
  # The fraction keeps the float's sign, e.g. -2.25 -> {-2, -0.25}.
  def split_float(float) when is_float(float) do
    whole = trunc(float)
    {whole, float - whole}
  end
end
