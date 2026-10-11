defmodule Curves.Utils.Constants do
  @moduledoc false

  # A small step, used e.g. to estimate a derivative from two nearby points.
  @spec small_number() :: float()
  def small_number(), do: 0.001
end
