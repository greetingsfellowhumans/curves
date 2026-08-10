defmodule Curves.Utils.Coord do
  @moduledoc false

  # Coords represent the user input which can be in the form of a tuple `{x, y}`, or a list `[x, y]`.

  # Always return a tuple, or list of tuples
  def normalize({_, _} = c), do: c
  def normalize([x, y]) when is_number(x) and is_number(y), do: {x, y}
  def normalize(li) when is_list(li), do: Enum.map(li, &normalize/1)

  # Return a list of numbers from the x column
  def filter_x(li) when is_list(li), do: normalize(li) |> Enum.map(&elem(&1, 0))
  def filter_y(li) when is_list(li), do: normalize(li) |> Enum.map(&elem(&1, 1))
end
