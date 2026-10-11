defmodule Curves.Utils.Numbers do
  @moduledoc false

  # Splits a float into its whole part and its fraction, e.g. 2.25 -> {2, 0.25}.
  # It works on the printed form of the float, so floats Elixir prints in scientific
  # notation (below 0.0001, e.g. 1.0e-5) give a fraction of 0.0, and a negative
  # float gives a positive fraction.
  @spec split_float(float()) :: {integer(), float()}
  def split_float(float) when is_float(float) do
    str = Float.to_string(float) |> String.split(".") |> List.last()
    {t, _} = Float.parse("0." <> str)
    {trunc(float), t}
  end
end
