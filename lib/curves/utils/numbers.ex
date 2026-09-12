defmodule Curves.Utils.Numbers do
  @moduledoc false

  def split_float(float) when is_float(float) do
    str = Float.to_string(float) |> String.split(".") |> List.last()
    {t, _} = Float.parse("0." <> str)
    {trunc(float), t}
  end



end
