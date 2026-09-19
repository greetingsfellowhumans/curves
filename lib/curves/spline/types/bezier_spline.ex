defmodule Curves.Spline.Type.BezierSpline do
  @moduledoc ~s"""
  The Bezier Spline is basically a series of Bezier Curves linked together.

  To define one, you pass in a list of curves, but without the endpoint, which is automatically calculated from the next curve


  ```elixir
  points = [
    # P0
    [{5.0, 10.0},  # Knot
    {10.0, 10.0}], # control point 0

    # P1
    [{10.0, 5.0},  # Knot
      {5.0, 5.0},  # control point 0
      {15.0, 5.0}],# control point 1

    # P2
    [{15.0, 10.0}, # Knot
    {15.0, 6.0},  # control point 0
    {15.0, 14.0}  # control point 1
    ],

    # P3
    [{20.0, 15.0}, # Knot
    {18.0, 15.0}, # control point 0
    {23.0, 15.0}],# control point 1

    # P4
    [{30.0, 10.0}, # Knot
      {32.0, 5.0}] # control point 0
  ]
  curves = Curves.define_bezier_spline(points)

  for i <- 0..1000 do
    Curves.solve!(curve, i / 1000)
  end
  |> # render_vega_lite_chart(...)
  ```

  ![Bezier Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/bezier_spline.png)

  """
  use Curves.Spline.Type


  @matrix ~MAT<
    1   0  0 0
    -3  3  0 0
    3  -6  3 0
    -1  3 -3 1
  >

  @doc false
  @impl true
  def define(points, opts \\ []) do
    Curves.define_spline(points, :bezier_spline, opts)
  end

  @doc false
  @impl true
  def point_count(), do: 4

  @doc false
  @impl true
  def blending_function(), do: @matrix

end
