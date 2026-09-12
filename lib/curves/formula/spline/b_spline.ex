defmodule Curves.Formula.BSpline do
  @moduledoc false
  use Curves.Formula,
    derivative: 1

  @matrix_new ~MAT<
    1   4  1 0
    -3  0  3 0
    3  -6  3 0
    -1  3 -3 1
  >
  @matrix_old ~MAT<
    -1  3 -3 1
    3  -6  3 0
    -3  0  3 0
    1   4  1 0
  >


  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix_new


  #@impl true
  #def points_function(points, _segment \\ 0) do 
  #  #points
  #  #  |> Curves.Utils.Points.point_at(segment)
  #  Nx.slice(points, [0, 0], [2, 4])
  #end
end
