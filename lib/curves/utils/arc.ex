defmodule Curves.Utils.Arc do
  @moduledoc false
  # Elliptical arcs: a kind of spline segment that isn't a polynomial.
  #
  # An arc is stored as {:arc, c, a, b, from, to, start, finish}: the ellipse's centre `c`, the ends
  # of its two axes `a` and `b` (points, not directions), the angles (in radians) it runs between,
  # and its exact start and end points, so it begins and ends exactly on its knots (working them out
  # from the angles would be off by rounding, e.g. {0.0, 6.1e-16} instead of {0.0, 0.0}). The point at
  # angle θ is
  #
  #     c + (a - c) * cos θ + (b - c) * sin θ
  #
  # The weights on c, a and b, (1 - cos θ - sin θ), cos θ and sin θ, always add up to 1. So moving,
  # scaling (even differently in x and y, or flipping) or rotating those three points moves the
  # whole arc exactly, the same way transforming a Bezier curve's points moves the curve. That is
  # how the transforms in Curves.Transform work on arcs without knowing about them.
  #
  # `u` moves through the angle at a steady rate: a steady speed on a circle, but not on an ellipse.
  alias Curves.Types, as: T
  alias Curves.Utils.Vec

  @type t() ::
          {:arc, T.point_tuple(), T.point_tuple(), T.point_tuple(), float(), float(),
           T.point_tuple(), T.point_tuple()}

  # What compress keeps for solving: the centre, the two axes as directions, the start angle, how
  # far the angle turns, and the exact start and end points.
  @type prepared() ::
          {:arc, T.point_tuple(), T.point_tuple(), T.point_tuple(), float(), float(),
           T.point_tuple(), T.point_tuple()}

  # An arc (or a prepared one).
  defguard is_arc(segment)
           when is_tuple(segment) and tuple_size(segment) == 8 and elem(segment, 0) == :arc

  # The largest angle one hull piece covers (see hull_points/1): a quarter turn.
  @quarter :math.pi() / 2

  # An arc of the ellipse with centre `c` and axis ends `a` and `b`, from angle `from` to `to`
  # (radians). `to` smaller than `from` goes the other way round.
  @spec new(T.point_tuple(), T.point_tuple(), T.point_tuple(), float(), float()) :: t()
  def new(c, a, b, from, to) do
    {from, to} = {from * 1.0, to * 1.0}
    start = point_at(c, a, b, from)

    {:arc, c, a, b, from, to, start,
     finish(whole_turns?(from, to), start, fn -> point_at(c, a, b, to) end)}
  end

  # A whole turn (or several) ends exactly where it starts.
  @spec finish(boolean(), T.point_tuple(), (-> T.point_tuple())) :: T.point_tuple()
  defp finish(true, start, _work_out), do: start
  defp finish(false, _start, work_out), do: work_out.()

  # Whether the arc goes round a whole number of times (and at least once).
  @spec whole_turns?(float(), float()) :: boolean()
  defp whole_turns?(from, to) do
    turns = abs(to - from) / (2 * :math.pi())
    turns >= 1 and abs(turns - round(turns)) < 1.0e-12
  end

  # The arc of an ellipse with radii rx and ry, its x axis tilted by `rotation` (radians), centred on `c`.
  @spec ellipse(T.point_tuple(), number(), number(), float(), float(), float()) :: t()
  def ellipse(c, rx, ry, rotation, from, to) do
    {cos, sin} = {:math.cos(rotation), :math.sin(rotation)}
    new(c, Vec.add(c, {rx * cos, rx * sin}), Vec.add(c, {-ry * sin, ry * cos}), from, to)
  end

  # SVG's arc command (`A rx ry rotation large_arc sweep x y`), from `p1` to `p2`, following the
  # SVG spec's implementation notes ("Elliptical arc implementation notes"). `rotation` is in
  # degrees. Like SVG:
  #   * the same start and end draws nothing, so the segment stays on that point,
  #   * a radius of 0 draws a straight line,
  #   * negative radii count as positive,
  #   * radii too small to reach p2 are scaled up until they just do.
  # Returns an arc, or (for the first two cases) an ordinary 4-point segment.
  @spec from_svg(
          T.point_tuple(),
          {number(), number(), number(), boolean(), boolean()},
          T.point_tuple()
        ) :: t() | list(T.point_tuple())
  def from_svg(p1, _spec, p2) when p1 == p2, do: [p1, p1, p1, p1]

  def from_svg({x1, y1} = p1, {rx, ry, rotation, large_arc, sweep}, {x2, y2} = p2) do
    phi = rotation * :math.pi() / 180
    {cos, sin} = {:math.cos(phi), :math.sin(phi)}

    # Step 1: p1, measured from the middle of p1 and p2, in the ellipse's own (unrotated) axes.
    {dx, dy} = {(x1 - x2) / 2, (y1 - y2) / 2}
    middle = {cos * dx + sin * dy, -sin * dx + cos * dy}
    radii = {abs(rx) * 1.0, abs(ry) * 1.0}

    shape = %{p1: p1, p2: p2, phi: phi, middle: middle, large_arc: large_arc, sweep: sweep}
    from_middle(shape, radii, flat?(radii, :math.sqrt(dx * dx + dy * dy)))
  end

  # Radii of 0 draw a straight line (SVG's rule). So do radii more than 1e100 times smaller than the
  # distance between the ends: they would overflow the maths below, and are a line to the eye.
  @spec flat?({float(), float()}, float()) :: boolean()
  defp flat?({rx, ry}, half), do: min(rx, ry) <= half * 1.0e-100

  @spec from_middle(map(), {float(), float()}, boolean()) :: t() | list(T.point_tuple())
  defp from_middle(%{p1: p1, p2: p2}, _radii, true), do: straight(p1, p2)

  defp from_middle(%{middle: {x, y}} = shape, {rx, ry}, false) do
    # How far outside the ellipse p1 is: more than 1 means the radii are too small to reach.
    # Written as (x / rx)² so huge radii can't overflow.
    lambda = x / rx * (x / rx) + y / ry * (y / ry)
    centre_from(shape, scale_radii(rx, ry, lambda), lambda)
  end

  # Radii billions of times bigger than the distance between the ends (lambda below 1e-20 means
  # about 5e9 times) are a straight line too. Such an arc is less than 1e-10 of that distance away
  # from the line, while its far-away centre would make each point lose most of its precision to
  # rounding (a point is the centre plus an axis, both huge, to get something small).
  @spec centre_from(map(), {float(), float()}, float()) :: t() | list(T.point_tuple())
  defp centre_from(%{p1: p1, p2: p2}, _radii, lambda) when lambda < 1.0e-20,
    do: straight(p1, p2)

  defp centre_from(shape, {rx, ry}, lambda) do
    %{p1: {x1, y1}, p2: {x2, y2}, phi: phi, middle: {x, y}} = shape
    {cos, sin} = {:math.cos(phi), :math.sin(phi)}

    # Step 2: the centre in the ellipse's axes. The spec's square root,
    # (rx²ry² - rx²y² - ry²x²) / (rx²y² + ry²x²), is (1 - lambda) / lambda, which can't overflow.
    # Scaled-up radii make lambda 1, so the root is 0; rounding can take it just below, so it is
    # kept at 0 or more.
    root = centre_side(shape) * :math.sqrt(max(0.0, (1 - min(lambda, 1.0)) / lambda))
    {ccx, ccy} = {root * rx * y / ry, -root * ry * x / rx}

    # Step 3: the centre in the real axes.
    c = {cos * ccx - sin * ccy + (x1 + x2) / 2, sin * ccx + cos * ccy + (y1 + y2) / 2}

    # Step 4: the start angle, and how far it turns: positive when `sweep` is true.
    start_dir = {(x - ccx) / rx, (y - ccy) / ry}
    start = angle({1.0, 0.0}, start_dir)
    turn = angle(start_dir, {(-x - ccx) / rx, (-y - ccy) / ry})

    {:arc, c, a, b, from, to, _start, _finish} =
      ellipse(c, rx, ry, phi, start, start + sweep_turn(turn, shape.sweep))

    # It starts and ends exactly on the knots.
    {:arc, c, a, b, from, to, shape.p1, shape.p2}
  end

  # Which side of the line from p1 to p2 the centre is on (the spec's sign).
  @spec centre_side(map()) :: -1 | 1
  defp centre_side(%{large_arc: same, sweep: same}), do: -1
  defp centre_side(_shape), do: 1

  # Radii scaled up (both by the same amount) when they are too small to reach from p1 to p2.
  @spec scale_radii(float(), float(), float()) :: {float(), float()}
  defp scale_radii(rx, ry, lambda) when lambda > 1 do
    k = :math.sqrt(lambda)
    {rx * k, ry * k}
  end

  defp scale_radii(rx, ry, _lambda), do: {rx, ry}

  # The signed angle from direction u to direction v, between -π and π. atan2 never fails, unlike
  # acos, which a rounding error just past 1.0 would crash.
  @spec angle(T.point_tuple(), T.point_tuple()) :: float()
  defp angle({ux, uy}, {vx, vy}), do: :math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)

  # The turn made to go the way `sweep` asks: positive (angle increasing) when true.
  @spec sweep_turn(float(), boolean()) :: float()
  defp sweep_turn(turn, true) when turn < 0, do: turn + 2 * :math.pi()
  defp sweep_turn(turn, false) when turn > 0, do: turn - 2 * :math.pi()
  defp sweep_turn(turn, _sweep), do: turn

  # A straight line from p1 to p2 at a steady speed, as a cubic Bezier segment.
  @spec straight(T.point_tuple(), T.point_tuple()) :: list(T.point_tuple())
  defp straight(p1, p2) do
    step = Vec.scale(Vec.subtract(p2, p1), 1 / 3)
    [p1, Vec.add(p1, step), Vec.subtract(p2, step), p2]
  end

  # Worked out once per arc in Spline.Curve.compress, so solving only needs one cos and one sin.
  @spec prepare(t()) :: prepared()
  def prepare({:arc, c, a, b, from, to, start, finish}),
    do: {:arc, c, Vec.subtract(a, c), Vec.subtract(b, c), from, to - from, start, finish}

  # The point `t` of the way along the arc (t = 0 is the start, 1 the end). The ends are exact.
  @spec eval(prepared(), number()) :: T.point_tuple()
  def eval({:arc, _c, _u, _v, _from, _turn, start, _finish}, t) when t == 0, do: start
  def eval({:arc, _c, _u, _v, _from, _turn, _start, finish}, t) when t == 1, do: finish

  def eval({:arc, {cx, cy}, {ux, uy}, {vx, vy}, from, turn, _start, _finish}, t) do
    theta = from + t * turn
    cos = :math.cos(theta)
    sin = :math.sin(theta)
    {cx + ux * cos + vx * sin, cy + uy * cos + vy * sin}
  end

  # The point at angle `theta`.
  @spec point_at(T.point_tuple(), T.point_tuple(), T.point_tuple(), float()) :: T.point_tuple()
  defp point_at(c, a, b, theta) do
    c
    |> Vec.add(Vec.scale(Vec.subtract(a, c), :math.cos(theta)))
    |> Vec.add(Vec.scale(Vec.subtract(b, c), :math.sin(theta)))
  end

  # The same arc travelled the other way.
  @spec reverse(t()) :: t()
  def reverse({:arc, c, a, b, from, to, start, finish}),
    do: {:arc, c, a, b, to, from, finish, start}

  # The arc with `fun` applied to its centre and axis ends, e.g. to scale or move it.
  @spec map_points(t(), (T.point_tuple() -> T.point_tuple())) :: t()
  def map_points({:arc, c, a, b, from, to, start, finish}, fun),
    do: {:arc, fun.(c), fun.(a), fun.(b), from, to, fun.(start), fun.(finish)}

  # Points the arc never goes outside of, like a Bezier curve's control points. The arc is cut into
  # pieces of at most a quarter turn; each piece lies inside the triangle made by its two ends and
  # the point where the tangents at those ends meet. Returns the start, then that corner and the
  # end of each piece in turn. Transforms keep this true, since they move straight lines and
  # tangents to straight lines and tangents.
  @spec hull_points(t()) :: T.point_list()
  def hull_points(arc) do
    [first | pieces] = pieces(arc)
    [first | Enum.flat_map(pieces, fn {corner, finish} -> [corner, finish] end)]
  end

  # The dashed lines for Curves.Svg: from each piece's start, to its corner, to its end. Like the
  # lines of a quadratic Bezier curve, whose one control point pulls on both ends.
  @spec hull_lines(t()) :: list(T.point_list())
  def hull_lines(arc) do
    [first | pieces] = pieces(arc)

    pieces
    |> Enum.map_reduce(first, fn {corner, finish}, start -> {[start, corner, finish], finish} end)
    |> elem(0)
  end

  # The start of the arc, then {corner, end} for each piece. The first and last points are the arc's
  # exact start and end.
  @spec pieces(t()) :: [T.point_tuple() | {T.point_tuple(), T.point_tuple()}]
  defp pieces({:arc, c, a, b, from, to, start, finish}) do
    # A tiny allowance so an exact quarter turn isn't split in two by rounding.
    count = max(1, ceil(abs(to - from) / @quarter - 1.0e-9))
    step = (to - from) / count
    # The corner is the middle of the piece, pushed out by 1 / cos(half the piece's angle).
    push = 1 / :math.cos(step / 2)

    corners =
      for i <- 1..count do
        middle = from + (i - 0.5) * step
        corner = Vec.add(c, Vec.scale(Vec.subtract(point_at(c, a, b, middle), c), push))
        {corner, piece_end(i, count, finish, point_at(c, a, b, from + i * step))}
      end

    [start | corners]
  end

  # The last piece ends exactly at the arc's end.
  @spec piece_end(pos_integer(), pos_integer(), T.point_tuple(), T.point_tuple()) ::
          T.point_tuple()
  defp piece_end(count, count, finish, _worked_out), do: finish
  defp piece_end(_i, _count, _finish, worked_out), do: worked_out
end
