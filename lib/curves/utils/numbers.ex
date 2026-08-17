defmodule Curves.Utils.Numbers do
  @moduledoc false

  def split_float(float) when is_float(float) do
    [idx, perc] = String.split("#{float}", ".")
    {String.to_integer(idx), String.to_float("0.#{perc}")}
  end
end
