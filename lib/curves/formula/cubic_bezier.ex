defmodule Curves.Formula.CubicBezier do
  @moduledoc false
  use Curves.Formula

  @matrix ~MAT<
    -1  3 -3 1
    3  -6  3 0
    -3  3  0 0
    1   0  0 0
  >

  @impl true
  def required_opts(), do: []

  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix

  @impl true
  def power_series(t), do: Nx.tensor([t ** 3, t ** 2, t, 1])

  @impl true
  def points_function(points), do: Nx.slice(points, [0, 0], [2, 4])
end
