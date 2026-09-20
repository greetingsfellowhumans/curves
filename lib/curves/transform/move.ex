defmodule Curves.Transform.Move do
  @moduledoc false
  import Curves.Utils.Point, only: [new_point: 1]


  def set_position(curve, origin) do
    transform(curve, fn _ -> new_point(origin) end)
  end


  def inc_position(curve, pos) do
    p = new_point(pos)
    transform(curve, fn origin ->  Nx.add(origin, p) end)
  end


  def inc_x(curve, xinc) do
    p = new_point({xinc, 0.0})
    transform(curve, fn origin ->  Nx.add(origin, p) end)
  end


  def inc_y(curve, yinc) do
    p = new_point({0.0, yinc})
    transform(curve, fn origin ->  Nx.add(origin, p) end)
  end

  #@impl true
  defp transform(curve, cb) do
    Map.update!(curve, :origin, cb)
  end

end

