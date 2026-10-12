defmodule Curves.Spline.Type.CentripetalCatmullRom do
  @moduledoc ~s"""
  A centripetal Catmull-Rom spline: like `Curves.Spline.Type.CatmullRom`, but it takes the
  distances between the knots into account, so it never makes little loops or sharp points
  (cusps), even when some knots are much closer together than others.

  You only give the knots, and the curve passes through every one of them. The `:alpha` option,
  between `0.0` and `1.0`, sets how much the distances count:

  | `:alpha` | Name | The curve... |
  | --- | --- | --- |
  | `0.0` | uniform | is exactly a `Curves.Spline.Type.CatmullRom` spline |
  | `0.5` (the default) | centripetal | never loops or makes cusps within a segment |
  | `1.0` | chordal | bends even more gently near knots that are far apart |

  A spline with `n` knots has `n - 1` segments, like Catmull-Rom.

  ```elixir
  # Two knots close together between two far away: plain Catmull-Rom makes a little loop here.
  curve = Curves.define_centripetal_catmull_rom([{0, 0}, {10, 10}, {10.5, 10}, {20, 0}])

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "centripetal_catmull_rom.svg")
  ```

  | Plain Catmull-Rom | Centripetal |
  | --- | --- |
  | ![Catmull-Rom makes a loop](images/spline_bunched_catmull_rom.svg) | ![Centripetal makes no loop](images/spline_centripetal.svg) |

  ## How it is built

  Each segment, from knot `p1` to knot `p2`, looks at the knots either side, `p0` and `p3`. With
  `d01`, `d12` and `d23` for the distances between them, each raised to the power `alpha`:

  ```text
  leaving p1  = p2 - p1 + d12 * ((p1 - p0) / d01 - (p2 - p0) / (d01 + d12))
  arriving p2 = p2 - p1 + d12 * ((p3 - p2) / d23 - (p3 - p1) / (d12 + d23))
  ```

  Each segment is the Hermite segment with those tangents, stored as a cubic Bezier curve, and
  `u` still adds one per segment. A knot's tangent can be longer on one side than the other, so the
  speed along the curve can jump at a knot, but its direction never does.

  The first and last knots have no knot on one side, so they get a made-up one, mirrored through
  the end (the same as Catmull-Rom). Two knots in the same place make a segment that stays on that
  point; a knot's neighbour in the same place is treated like the end of the curve.
  """
  use Curves.Spline.Type

  alias Curves.Types, as: T
  alias Curves.Utils.{Hermite, Opts, Segment, Vec}

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  @doc false
  @impl true
  def define(points, opts \\ []) do
    opts = Opts.put_numbers!(opts, alpha: 0.5)
    check_alpha!(Keyword.fetch!(opts, :alpha))

    points
    |> Enum.map(&[&1])
    |> Curves.define_spline(:centripetal_catmull_rom, opts)
  end

  @spec check_alpha!(float()) :: :ok
  defp check_alpha!(alpha) when alpha >= 0.0 and alpha <= 1.0, do: :ok

  defp check_alpha!(alpha) do
    raise ArgumentError, "the :alpha option must be between 0.0 and 1.0, got: #{inspect(alpha)}"
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Replaces the straight segments between the knots with the curve's Bezier segments.
  @doc false
  @impl true
  def map_segments(_segments, %{points: [knot]}), do: [Hermite.stay(knot)]

  def map_segments(_segments, %{points: knots, opts: opts}) do
    alpha = Keyword.get(opts, :alpha, 0.5)

    knots
    |> Hermite.with_mirrored_ends()
    |> Enum.chunk_every(4, 1, :discard)
    |> Enum.map(&segment(&1, alpha))
  end

  # The segment from p1 to p2, see "How it is built" above.
  @spec segment(T.point_list(), float()) :: Segment.t()
  defp segment([p0, p1, p2, p3], alpha) do
    segment(p0, p1, p2, p3, alpha, gap(p1, p2, alpha))
  end

  # Two knots in the same place: the segment stays there. Only possible when alpha > 0, since
  # with alpha = 0 every gap is 1.0 (0.0 to the power 0 is 1).
  @spec segment(
          T.point_tuple(),
          T.point_tuple(),
          T.point_tuple(),
          T.point_tuple(),
          float(),
          float()
        ) ::
          Segment.t()
  defp segment(_p0, p1, _p2, _p3, _alpha, d12) when d12 == 0.0, do: Hermite.stay(p1)

  defp segment(p0, p1, p2, p3, alpha, d12) do
    # A neighbour in the same place as its knot gives no direction, so treat it like an end.
    p0 = away_from(p0, p1, p2, alpha)
    p3 = away_from(p3, p2, p1, alpha)
    d01 = gap(p0, p1, alpha)
    d23 = gap(p2, p3, alpha)
    chord = Vec.subtract(p2, p1)
    leaving = tangent(chord, d12, {Vec.subtract(p1, p0), d01}, {Vec.subtract(p2, p0), d01 + d12})
    arriving = tangent(chord, d12, {Vec.subtract(p3, p2), d23}, {Vec.subtract(p3, p1), d12 + d23})

    Hermite.bezier_segment(p1, leaving, p2, arriving)
  end

  # chord + d12 * (a / da - b / db): both tangent formulas in "How it is built" have this shape.
  @spec tangent(T.point_tuple(), float(), {T.point_tuple(), float()}, {T.point_tuple(), float()}) ::
          T.point_tuple()
  defp tangent(chord, d12, {a, da}, {b, db}),
    do: Vec.add(chord, Vec.scale(Vec.subtract(Vec.scale(a, 1 / da), Vec.scale(b, 1 / db)), d12))

  # `neighbour`, or, when it is in the same place as `knot`, `other` mirrored through `knot`.
  @spec away_from(T.point_tuple(), T.point_tuple(), T.point_tuple(), float()) :: T.point_tuple()
  defp away_from(neighbour, knot, other, alpha),
    do: pick(neighbour, knot, other, gap(neighbour, knot, alpha))

  @spec pick(T.point_tuple(), T.point_tuple(), T.point_tuple(), float()) :: T.point_tuple()
  defp pick(_neighbour, knot, other, gap) when gap == 0.0, do: Hermite.mirror(knot, other)
  defp pick(neighbour, _knot, _other, _gap), do: neighbour

  # The distance between two points to the power alpha.
  @spec gap(T.point_tuple(), T.point_tuple(), float()) :: float()
  defp gap({x0, y0}, {x1, y1}, alpha) do
    dx = x1 - x0
    dy = y1 - y0
    :math.pow(:math.sqrt(dx * dx + dy * dy), alpha)
  end
end
