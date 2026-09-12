defmodule Curves.Formula.BezierSpline do
  @moduledoc false
  use Curves.Formula


  @matrix ~MAT<
    1   0  0 0
    -3  3  0 0
    3  -6  3 0
    -1  3 -3 1
  >

  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix

end
