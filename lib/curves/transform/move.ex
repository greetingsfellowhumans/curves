defmodule Curves.Transform.Move do
  @moduledoc false
  alias Curves.Types, as: T
  alias Curves.Utils.Vec

  # These only change the curve's :origin field. The points are moved later, in compress.
  @spec set_position(T.curve_struct(), T.point_tuple()) :: T.curve_struct()
  def set_position(curve, origin) do
    transform(curve, fn _ -> Vec.new(origin) end)
  end

  @spec inc_position(T.curve_struct(), T.point_tuple()) :: T.curve_struct()
  def inc_position(curve, pos) do
    transform(curve, &Vec.add(&1, Vec.new(pos)))
  end

  @spec inc_x(T.curve_struct(), number()) :: T.curve_struct()
  def inc_x(curve, xinc) do
    transform(curve, &Vec.add(&1, Vec.new({xinc, 0.0})))
  end

  @spec inc_y(T.curve_struct(), number()) :: T.curve_struct()
  def inc_y(curve, yinc) do
    transform(curve, &Vec.add(&1, Vec.new({0.0, yinc})))
  end

  @spec transform(T.curve_struct(), (T.point_tuple() -> T.point_tuple())) :: T.curve_struct()
  defp transform(curve, cb) do
    Map.update!(curve, :origin, cb)
  end
end
