defmodule Curves.Spline.Type.BSpline do
  @moduledoc false
  use Curves.Spline.Type


  @matrix ~MAT<
    1   4  1 0
    -3  0  3 0
    3  -6  3 0
    -1  3 -3 1
  >

  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix

  @impl true
  def power_series(t) do
    [1, t, t ** 2, t ** 3]
    |> Nx.tensor()
    |> Nx.divide(6)
  end

end
