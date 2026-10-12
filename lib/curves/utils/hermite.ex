defmodule Curves.Utils.Hermite do
  @moduledoc false
  # Shared maths for the splines that are Hermite splines underneath: Hermite itself, and the
  # splines that work out each knot's tangent for you (Cardinal, Kochanek-Bartels, centripetal
  # Catmull-Rom, monotone and natural cubic).
  #
  # A Hermite segment from knot p0 (leaving with tangent m0) to knot p1 (arriving with tangent m1)
  # is exactly the cubic Bezier curve [p0, p0 + m0 / 3, p1 - m1 / 3, p1], so every one of these
  # splines is stored and solved as Bezier segments.
  alias Curves.Types, as: T
  alias Curves.Utils.{Segment, Vec}

  # A knot with the tangent the curve arrives with and the tangent it leaves with.
  # Most splines use the same tangent on both sides; Kochanek-Bartels can use two.
  @type knot_tangents() :: {T.point_tuple(), T.point_tuple(), T.point_tuple()}

  # The Bezier segment for one Hermite segment, see the top of this module.
  @spec bezier_segment(T.point_tuple(), T.point_tuple(), T.point_tuple(), T.point_tuple()) ::
          Segment.t()
  def bezier_segment(p0, m0, p1, m1),
    do: [p0, Vec.add(p0, Vec.scale(m0, 1 / 3)), Vec.subtract(p1, Vec.scale(m1, 1 / 3)), p1]

  # One Bezier segment per pair of neighbouring knots: each leaves a knot with its outgoing tangent
  # and arrives at the next with that knot's incoming tangent. A single knot is one segment that
  # stays on it, like a one-knot Catmull-Rom spline.
  @spec bezier_segments(nonempty_list(knot_tangents())) :: list(Segment.t())
  def bezier_segments([{knot, _in, _out}]), do: [stay(knot)]

  def bezier_segments(knots) do
    knots
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{p0, _in0, out0}, {p1, in1, _out1}] -> bezier_segment(p0, out0, p1, in1) end)
  end

  # Each knot with one tangent, used on both sides of it.
  @spec same_both_sides(T.point_list(), T.point_list()) :: list(knot_tangents())
  def same_both_sides(knots, tangents), do: Enum.zip_with(knots, tangents, &{&1, &2, &2})

  # A segment that stays on one point.
  @spec stay(T.point_tuple()) :: Segment.t()
  def stay(point), do: [point, point, point, point]

  # The knots with a made-up knot added before the first and after the last, so every real knot
  # has a neighbour on each side. Each made-up knot is the end's neighbour mirrored through the
  # end, the same as Catmull-Rom: the curve then leaves (and arrives at) each end heading straight
  # for its neighbour. Needs at least 2 knots.
  @spec with_mirrored_ends(T.point_list()) :: T.point_list()
  def with_mirrored_ends([first, second | _] = knots) do
    [last, second_last | _] = Enum.reverse(knots)
    [mirror(first, second) | knots] ++ [mirror(last, second_last)]
  end

  # Each knot with the knots either side of it: {previous, knot, next}. Needs at least 2 knots.
  @spec neighbours(T.point_list()) :: list({T.point_tuple(), T.point_tuple(), T.point_tuple()})
  def neighbours(knots) do
    knots
    |> with_mirrored_ends()
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.map(&List.to_tuple/1)
  end

  # `point` mirrored through `centre`: as far past `centre` as `point` is before it.
  @spec mirror(T.point_tuple(), T.point_tuple()) :: T.point_tuple()
  def mirror(centre, point), do: Vec.subtract(Vec.scale(centre, 2), point)
end
