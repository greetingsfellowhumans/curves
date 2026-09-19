defmodule Curves.Spline.Type.BezierSpline do
  @moduledoc false
  use Curves.Spline.Type


  @matrix ~MAT<
    1   0  0 0
    -3  3  0 0
    3  -6  3 0
    -1  3 -3 1
  >

  @impl true
  def define(points, opts \\ []) do
    Curves.define_spline(points, :bezier_spline, opts)
  end

  @impl true
  def point_count(), do: 4

  @impl true
  def blending_function(), do: @matrix

end
