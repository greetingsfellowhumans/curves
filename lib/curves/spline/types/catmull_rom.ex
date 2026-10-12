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

  # A segment, [p0, p1, p2, p3], paired with its index.
  @typep indexed_segment :: {Segment.t(), non_neg_integer()}

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
    Enum.map(all_segments, fn {[p1, _, _, p2] = segment, segment_idx} ->
      [
        get_prev_coord(all_segments, segment_idx, segment),
        p1,
        p2,
        get_next_coord(all_segments, segment_idx, segment)
      ]
    end)
  end

  # The point before this segment's start: the previous segment's first point, or a mirrored point at the start.
  @doc false
  @spec get_prev_coord(list(indexed_segment()), non_neg_integer(), Segment.t()) :: T.point_tuple()
  def get_prev_coord(all_segments, segment_idx, [p1, _, _, p2]) do
    case Enum.at(all_segments, segment_idx - 1) do
      {[p0 | _], _idx} when segment_idx > 0 -> p0
      _ -> Vec.add(p1, Vec.subtract(p1, p2))
    end
  end

  # The point after this segment's end: the next segment's last point, or a mirrored point at the end.
  @doc false
  @spec get_next_coord(list(indexed_segment()), non_neg_integer(), Segment.t()) :: T.point_tuple()
  def get_next_coord(all_segments, segment_idx, [p1, _, _, p2]) do
    case Enum.at(all_segments, segment_idx + 1) do
      {[_, _, _, p3], _idx} -> p3
      # Just mirror the slope from here to the next point
      nil -> Vec.add(p2, Vec.subtract(p2, p1))
    end
  end
end
