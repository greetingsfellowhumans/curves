defmodule Curves.Spline.Type.BezierSpline do
  @moduledoc false
  use Curves.Spline.Type,
    derivative: 1


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
