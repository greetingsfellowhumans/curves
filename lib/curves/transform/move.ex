defmodule Curves.Transform.Move do
  @moduledoc false
  import Curves.Utils.Point, only: [new_point: 1]
  alias Curves.TensorTypes, as: TensorT
  alias Curves.Types, as: T

  # These only change the curve's :origin field. The points are moved later, in compress.
  @spec set_position(T.curve_struct(), T.point_tuple()) :: T.curve_struct()
  def set_position(curve, origin) do
    transform(curve, fn _ -> new_point(origin) end)
  end

  @spec inc_position(T.curve_struct(), T.point_tuple()) :: T.curve_struct()
  def inc_position(curve, pos) do
    p = new_point(pos)
    transform(curve, fn origin -> Nx.add(origin, p) end)
  end

  @spec inc_x(T.curve_struct(), number()) :: T.curve_struct()
  def inc_x(curve, xinc) do
    p = new_point({xinc, 0.0})
    transform(curve, fn origin -> Nx.add(origin, p) end)
  end

  @spec inc_y(T.curve_struct(), number()) :: T.curve_struct()
  def inc_y(curve, yinc) do
    p = new_point({0.0, yinc})
    transform(curve, fn origin -> Nx.add(origin, p) end)
  end

  @spec transform(T.curve_struct(), (TensorT.point() -> TensorT.point())) :: T.curve_struct()
  defp transform(curve, cb) do
    Map.update!(curve, :origin, cb)
  end
end
