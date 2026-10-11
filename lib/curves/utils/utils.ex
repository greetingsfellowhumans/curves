defmodule Curves.Utils do
  @moduledoc false
  alias Curves.Utils.TensorTypes, as: TensorT
  alias Curves.Utils.Types, as: T

  _comment = "Generates a tensor representing a single 2d point in space."
  @spec new_2d_point(T.point_tuple() | [T.coord()], T.opts()) :: TensorT.point()
  defdelegate new_2d_point(tup, opts), to: __MODULE__.Point, as: :new_point

  @spec new_2d_point(T.coord(), T.coord(), T.opts()) :: TensorT.point()
  defdelegate new_2d_point(x, y, opts), to: __MODULE__.Point, as: :new_point
end
