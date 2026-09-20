defmodule Curves.Transform.Scale do
  @moduledoc false
  #import Curves.Utils.Point, only: [new_point: 1]


  def set_scale(curve, scale) do
    transform(curve, fn _ -> scale end)
  end


  #def inc_position(curve, pos) do
  #  p = new_point(pos)
  #  transform(curve, fn origin ->  Nx.add(origin, p) end)
  #end


  #def inc_x(curve, xinc) do
  #  p = new_point({xinc, 0.0})
  #  transform(curve, fn origin ->  Nx.add(origin, p) end)
  #end


  #def inc_y(curve, yinc) do
  #  p = new_point({0.0, yinc})
  #  transform(curve, fn origin ->  Nx.add(origin, p) end)
  #end

  #@impl true
  defp transform(curve, cb) do
    Map.update!(curve, :scale, cb)
  end

end

