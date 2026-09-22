defmodule Curves.Transform.Scale do
  @moduledoc false
  #import Curves.Utils.Point, only: [new_point: 1]


  def set_scale(curve, scale) do
    transform(curve, fn _ -> scale end)
  end


  def inc_scale(curve, amount) do
    transform(curve, fn scale ->  scale + amount end)
  end


  #@impl true
  defp transform(curve, cb) do
    Map.update!(curve, :scale, cb)
  end

end

