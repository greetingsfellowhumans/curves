defmodule Curves.Spline.Type.CatmullRom do
  @moduledoc ~s"""
  An implementation of the Catmull-Rom spline.

  Similar to [Curves.Spline.Type.Hermite], except that the derivative of each point is the slope of the previous and next point.

  This makes a smooth, C1 continuous spline.


  ```elixir
  curve = Curves.define_catmull_rom([
    {0, 0},
    {1, 0},
    {1, 1},
    {0, 1},
    {0, 2},
    {1, 2},
  ])

  for i <- 0..1000 do
    Curves.solve!(curve, i / 1000)
  end
  |> # render_vega_lite_chart(...)
  ```

  ![Catmull-Rom Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/catmull_rom.png)
  """
  use Curves.Spline.Type

  @doc false
  @impl true
  def define(points, opts \\ []) do
    Enum.map(points, &([&1]))
      |> Curves.define_spline(:catmull_rom, opts)
  end

  # Pk-1 == x0/y0
  # Pk   == x1/y1
  # Pk+1 == x2/y2
  # Pk+2 == x3/y3
  @matrix ~MAT<
    0 2 0 0
    -1 0 1 0
    2 -5 4 -1
    -1 3 -3 1
  >


  @doc false
  @impl true
  def point_count(), do: 4

  @doc false
  @impl true
  def blending_function(), do: @matrix

  @doc false
  @impl true
  def power_series(t) do
    [1, t, t ** 2, t ** 3]
    |> Nx.tensor()
    |> Nx.divide(2)
  end


  @doc false
  @impl true
  def map_segments(all_segments, _curve) do
    Enum.map(all_segments, fn {[ [x1, _, _, x2], [y1, _, _, y2] ] = segment, segment_idx} ->
      {x0, y0} = get_prev_coord(all_segments, segment_idx, segment)
      {x3, y3} = get_next_coord(all_segments, segment_idx, segment)

      map_segment([ [x0, x1, x2, x3], [y0, y1, y2, y3] ])
    end)
  end

  @doc false
  def map_segment([[x0, x1, x2, x3], [y0, y1, y2, y3]]) do
  [
      [x0, x1, x2, x3],
      [y0, y1, y2, y3]
  ]
  end

  @doc false
  def get_prev_coord(all_segments, segment_idx, [ [x1, _, _, x2], [y1, _, _, y2] ]) do
    prev_idx = segment_idx - 1
    if prev_idx >= 0 do
      prev_seg = Enum.at(all_segments, segment_idx - 1)
      {[ [x0, _, _, _x1], [y0, _, _, _y1] ], _idx} = prev_seg
      {x0, y0}
    else
      x = x1 + (x1 - x2)
      y = y1 + (y1 - y2)
      {x, y}
    end
  end

  @doc false
  def get_next_coord(all_segments, segment_idx, [ [x1, _, _, x2], [y1, _, _, y2] ]) do
    next_seg = Enum.at(all_segments, segment_idx + 1)
    case next_seg do
      {[ [_, _, _, x3], [_, _, _, y3] ], _idx} -> {x3, y3}

      # Just mirror the slope from here to the next point
      nil ->
        x = x2 + (x2 - x1)
        y = y2 + (y2 - y1)
        {x, y}
    end
  end



end
