defmodule Curves.Spline.Type.CatmullRom do
  @moduledoc ~s"""
  An implementation of the Catmull-Rom spline.

  A `Curves.Spline.Type.Hermite` spline whose tangents are worked out for you: the tangent at each knot is half the
  distance from the previous knot to the next one, so you only give the knots.

  This makes a smooth, C1 continuous spline.

  It has relatives that work the same way, with something extra: `Curves.Spline.Type.Cardinal` adds a
  `:tension`, `Curves.Spline.Type.CentripetalCatmullRom` never makes loops when knots are bunched up,
  and `Curves.Spline.Type.KochanekBartels` adds tension, continuity and bias dials.


  ```elixir
  curve = Curves.define_catmull_rom([
    {0, 0},
    {1, 0},
    {1, 1},
    {0, 1},
    {0, 2},
    {1, 2},
  ])

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "catmull_rom.svg")
  ```

  ![Catmull-Rom Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/catmull_rom.svg)
  """
  use Curves.Spline.Type

  alias Curves.Types, as: T
  alias Curves.Utils.{Segment, Vec}

  @doc false
  @impl true
  def define(points, opts \\ []) do
    points
    |> Enum.map(&[&1])
    |> Curves.define_spline(:catmull_rom, opts)
  end

  # Pk-1 == x0/y0
  # Pk   == x1/y1
  # Pk+1 == x2/y2
  # Pk+2 == x3/y3
  @matrix [[0, 2, 0, 0], [-1, 0, 1, 0], [2, -5, 4, -1], [-1, 3, -3, 1]]

  @doc false
  @impl true
  def blending_function(), do: @matrix

  @doc false
  @impl true
  def blending_factor(), do: 0.5

  @doc false
  @impl true
  def map_segments(all_segments, _curve) do
    # Each segment with the one before and after it (nil at the ends), in one pass.
    segments = Enum.map(all_segments, fn {segment, _idx} -> segment end)

    Enum.zip_with(
      [[nil | segments], segments, Enum.drop(segments, 1) ++ [nil]],
      fn [before, [p1, _, _, p2] = segment, next] ->
        [prev_coord(before, segment), p1, p2, next_coord(next, segment)]
      end
    )
  end

  # The point before a segment's start: the previous segment's first point, or a mirrored point at
  # the start.
  @spec prev_coord(Segment.t() | nil, Segment.t()) :: T.point_tuple()
  defp prev_coord(nil, [p1, _, _, p2]), do: Vec.add(p1, Vec.subtract(p1, p2))
  defp prev_coord([p0 | _], _segment), do: p0

  # The point after a segment's end: the next segment's last point, or (at the end) the slope from
  # the segment's start to its end, mirrored.
  @spec next_coord(Segment.t() | nil, Segment.t()) :: T.point_tuple()
  defp next_coord(nil, [p1, _, _, p2]), do: Vec.add(p2, Vec.subtract(p2, p1))
  defp next_coord([_, _, _, p3], _segment), do: p3
end
