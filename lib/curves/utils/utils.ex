defmodule Curves.Utils do
  @moduledoc false
  _comment = "Generates a new uuid_v7"
  defdelegate generate_uuid_v7(), to: __MODULE__.UuidV7

  _comment = "Generates a tensor representing a single 2d point in space."
  defdelegate new_2d_point(tup, opts), to: __MODULE__.Point, as: :new_point
  defdelegate new_2d_point(x, y, opts), to: __MODULE__.Point, as: :new_point
end
