defmodule Curves.Formula.Hermite do
  @moduledoc ~s"""
  Hermite splines accept no control points. Only knots.
  Control points are calculated automatically based on the first derivative of each knot.
  """
  use Curves.Formula,
    derivative: 0

  @matrix_new ~MAT<
    1 0 0 0
    0 1 0 0
    -3 -2 3 -1
    2 1 -2 1
  >


  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix_new

  # Points: [P0, P'0, P1, P'1]
  def point_matrix(), do: [{0, 0}, {0, 1}, {1, 0}, {1, 1}]

  @impl true
  def points_function(points) do
    dbg points
    {dimensions, size} = Nx.shape(points)
    Nx.slice(points, [0, 0], [dimensions, size])
  end
  #@impl true
  #def points_function(points, _segment \\ 0) do 
  #end
  # Converting hermite to control points
  # Given [H0, H1]
  # [
  #   H0,
  #   H0 + derivative(H0, 1) / 3
  #   H1 + derivative(H1, 1) / 3
  #   H1
  # ]
end
