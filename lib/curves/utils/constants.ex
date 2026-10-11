defmodule Curves.Utils.Constants do
  @moduledoc false

  # How far below 0 a spline's u may go (Spline.Curve's @minimum_u), to absorb float rounding.
  @spec small_number() :: float()
  def small_number(), do: 0.001
end
