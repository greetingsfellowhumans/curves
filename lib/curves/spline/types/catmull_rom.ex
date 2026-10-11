defmodule Curves.Spline.Type.CatmullRom do
  @moduledoc ~s"""
  An implementation of the Catmull-Rom spline.

  Similar to `Curves.Spline.Type.Hermite`, except that the derivative of each point is the slope of the previous and next point.

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

  # Find any point along the curve (u goes from 0.0 to curve.max_u)...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "catmull_rom.svg")
  ```

  ![Catmull-Rom Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/catmull_rom.svg)
  """
  use Curves.Spline.Type

  alias Curves.Utils.Types, as: T

  # A segment as nested lists, [[x0, x1, x2, x3], [y0, y1, y2, y3]], paired with its index.
  @type indexed_segment :: {list(list(number())), non_neg_integer()}

  @doc false
  @impl true
  def define(points, opts \\ []) do
    Enum.map(points, &[&1])
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
    Enum.map(all_segments, fn {[[x1, _, _, x2], [y1, _, _, y2]] = segment, segment_idx} ->
      {x0, y0} = get_prev_coord(all_segments, segment_idx, segment)
      {x3, y3} = get_next_coord(all_segments, segment_idx, segment)

      map_segment([[x0, x1, x2, x3], [y0, y1, y2, y3]])
    end)
  end

  @doc false
  @spec map_segment(list(list(number()))) :: list(list(number()))
  def map_segment([[x0, x1, x2, x3], [y0, y1, y2, y3]]) do
    [
      [x0, x1, x2, x3],
      [y0, y1, y2, y3]
    ]
  end

  # The point before this segment's start: the previous segment's first point, or a mirrored point at the start.
  @doc false
  @spec get_prev_coord(list(indexed_segment()), non_neg_integer(), list(list(number()))) ::
          T.point_tuple()
  def get_prev_coord(all_segments, segment_idx, [[x1, _, _, x2], [y1, _, _, y2]]) do
    prev_idx = segment_idx - 1

    if prev_idx >= 0 do
      prev_seg = Enum.at(all_segments, segment_idx - 1)
      {[[x0, _, _, _x1], [y0, _, _, _y1]], _idx} = prev_seg
      {x0, y0}
    else
      x = x1 + (x1 - x2)
      y = y1 + (y1 - y2)
      {x, y}
    end
  end

  # The point after this segment's end: the next segment's last point, or a mirrored point at the end.
  @doc false
  @spec get_next_coord(list(indexed_segment()), non_neg_integer(), list(list(number()))) ::
          T.point_tuple()
  def get_next_coord(all_segments, segment_idx, [[x1, _, _, x2], [y1, _, _, y2]]) do
    next_seg = Enum.at(all_segments, segment_idx + 1)

    case next_seg do
      {[[_, _, _, x3], [_, _, _, y3]], _idx} ->
        {x3, y3}

      # Just mirror the slope from here to the next point
      nil ->
        x = x2 + (x2 - x1)
        y = y2 + (y2 - y1)
        {x, y}
    end
  end
end
