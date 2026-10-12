defmodule Curves.Svg.PathWriter do
  @moduledoc false
  # Writes a curve as SVG path data, exactly: Bezier segments as C (or L and Q for a straight or
  # quadratic Bezier curve), polylines as L, and arcs as A. Used by Curves.Svg.path_data/1.
  #
  # An arc is stored by its centre and two axis ends (see Curves.Utils.Arc), which after a skew or
  # an uneven scale aren't at right angles any more. SVG's A needs the ellipse's real radii and
  # tilt, so they are found with a 2x2 singular value decomposition. Each arc is written in pieces
  # of less than 180 degrees, so SVG's large-arc flag is always 0 and never ambiguous, and a whole
  # ellipse (which starts and ends in the same place, which A can't draw) works too.
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Polyline.Curve, as: Polyline
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Types, as: T
  alias Curves.Utils.{Errors, Segment}
  import Curves.Utils.Arc, only: [is_arc: 1]

  # Each written arc piece turns less than this (0.9 of a half turn).
  @max_piece 0.9 * :math.pi()

  # `move` is applied to every point first, e.g. to write a shape in its own coordinates. It must be
  # affine (a matrix), so that it moves arcs exactly too.
  @spec path_data(T.curve_struct(), (T.point_tuple() -> T.point_tuple())) :: String.t()
  def path_data(curve, move \\ &Function.identity/1) do
    cond do
      is_struct(curve, Bezier) ->
        curve |> Bezier.transformed_points() |> Enum.map(move) |> bezier()

      is_struct(curve, Spline) ->
        curve |> Spline.bezier_segments() |> Enum.map(&Segment.map_points(&1, move)) |> spline()

      is_struct(curve, Polyline) ->
        curve |> Polyline.transformed_points() |> Enum.map(move) |> polyline()

      true ->
        Errors.raise_not_a_curve(curve)
    end
  end

  # A single Bezier curve: L, Q or C by its number of points. One point is a dot (M only).
  @spec bezier(T.point_list()) :: String.t()
  defp bezier([p0]), do: "M" <> point(p0)
  defp bezier([p0, p1]), do: "M" <> point(p0) <> " L" <> point(p1)
  defp bezier([p0, c, p1]), do: "M" <> point(p0) <> " Q" <> points([c, p1])
  defp bezier([p0, c0, c1, p1]), do: "M" <> point(p0) <> " C" <> points([c0, c1, p1])

  defp bezier(points) do
    raise ArgumentError,
          "SVG path data can only draw a Bezier curve of 1 to 4 points, got #{length(points)}"
  end

  @spec polyline(T.point_list()) :: String.t()
  defp polyline([first | rest]),
    do: Enum.join(["M" <> point(first) | Enum.map(rest, &("L" <> point(&1)))], " ")

  # M to the start, then one command (or several, for a long arc) per segment.
  @spec spline(list()) :: String.t()
  defp spline([first | _] = segments) do
    Enum.join(["M" <> point(start(first)) | Enum.flat_map(segments, &segment/1)], " ")
  end

  @spec start(list() | tuple()) :: T.point_tuple()
  defp start({:arc, _c, _a, _b, _from, _to, start, _finish}), do: start
  defp start([p0 | _]), do: p0

  @spec segment(list() | tuple()) :: list(String.t())
  defp segment(arc) when is_arc(arc), do: arc_commands(arc)
  defp segment([p0, c0, c1, p1] = cubic), do: [cubic_command(cubic, straight?(p0, c0, c1, p1))]

  # A cubic whose control points are a third and two thirds of the way along the line (how straight
  # lines are stored) is that line, travelled at a steady speed, so it is written as L.
  @spec cubic_command(list(T.point_tuple()), boolean()) :: String.t()
  defp cubic_command([_p0, _c0, _c1, p1], true), do: "L" <> point(p1)
  defp cubic_command([_p0, c0, c1, p1], false), do: "C" <> points([c0, c1, p1])

  @spec straight?(T.point_tuple(), T.point_tuple(), T.point_tuple(), T.point_tuple()) :: boolean()
  defp straight?({x0, y0}, {ax, ay}, {bx, by}, {x1, y1}) do
    {dx, dy} = {x1 - x0, y1 - y0}
    # Rounding allowance, relative to the size of the numbers.
    tolerance = 1.0e-12 * Enum.max([1.0, abs(x0), abs(y0), abs(x1), abs(y1)])

    abs(ax - (x0 + dx / 3)) <= tolerance and abs(ay - (y0 + dy / 3)) <= tolerance and
      abs(bx - (x0 + 2 * dx / 3)) <= tolerance and abs(by - (y0 + 2 * dy / 3)) <= tolerance
  end

  # An arc as A commands, in pieces of less than 180 degrees.
  @spec arc_commands(tuple()) :: list(String.t())
  defp arc_commands({:arc, c, a, b, from, to, _start, finish}) do
    u = Curves.Utils.Vec.subtract(a, c)
    v = Curves.Utils.Vec.subtract(b, c)
    {rx, ry, rotation, flipped, theta} = axes(u, v)
    shape = %{c: c, u: u, v: v, from: from, to: to, finish: finish}
    arc_pieces(shape, {rx, ry, rotation, flipped}, flat?(rx, ry), theta)
  end

  # An ellipse with no width goes back and forth along a line. SVG draws an A with a zero radius as
  # one straight line from start to end, which would cut the turns off, so it is written as lines
  # that break where it turns round: where its angle on the long axis passes 0 or 180 degrees.
  @spec flat?(float(), float()) :: boolean()
  defp flat?(rx, ry), do: ry <= rx * 1.0e-12

  @spec arc_pieces(map(), tuple(), boolean(), float()) :: list(String.t())
  defp arc_pieces(%{from: from, to: to} = shape, _axes, true = _flat, theta) do
    # The angle t where t + theta is a whole number of half turns, strictly between from and to.
    {low, high} = Enum.min_max([from, to])
    first = ceil((low + theta) / :math.pi())
    last = floor((high + theta) / :math.pi())

    turns =
      for k <- first..last//1, t = k * :math.pi() - theta, t > low and t < high, do: t

    turns = if to < from, do: Enum.reverse(turns), else: turns
    Enum.map(turns, &("L" <> point(at(shape, &1)))) ++ ["L" <> point(shape.finish)]
  end

  defp arc_pieces(%{from: from, to: to} = shape, {rx, ry, rotation, flipped}, false, _theta) do
    count = max(1, ceil(abs(to - from) / @max_piece))
    step = (to - from) / count
    # The angle goes up in SVG's sense when it does here, unless the axes were mirrored.
    sweep = sweep_flag(step > 0, flipped)

    for i <- 1..count do
      ending = piece_end(shape, i, count, from + i * step)
      "A" <> Enum.join([number(rx), number(ry), number(rotation), "0", sweep, point(ending)], " ")
    end
  end

  @spec sweep_flag(boolean(), boolean()) :: String.t()
  defp sweep_flag(same, same), do: "0"
  defp sweep_flag(_up, _flipped), do: "1"

  # The last piece ends exactly at the arc's end.
  @spec piece_end(map(), pos_integer(), pos_integer(), float()) :: T.point_tuple()
  defp piece_end(%{finish: finish}, count, count, _theta), do: finish
  defp piece_end(shape, _i, _count, theta), do: at(shape, theta)

  @spec at(map(), float()) :: T.point_tuple()
  defp at(%{c: {cx, cy}, u: {ux, uy}, v: {vx, vy}}, theta) do
    {cx + ux * :math.cos(theta) + vx * :math.sin(theta),
     cy + uy * :math.cos(theta) + vy * :math.sin(theta)}
  end

  # The real radii and tilt (in degrees) of the ellipse c + u cos t + v sin t, whether u and v are
  # mirrored (so the angle goes the other way), and theta: the ellipse's own angle is t + theta.
  # This is the closed-form SVD of the 2x2 matrix [u v] = rotate(phi) * scale(rx, ±ry) * rotate(theta).
  @spec axes(T.point_tuple(), T.point_tuple()) :: {float(), float(), float(), boolean(), float()}
  defp axes({a, b}, {c, d}) do
    e = (a + d) / 2
    f = (a - d) / 2
    g = (b + c) / 2
    h = (b - c) / 2
    q = :math.sqrt(e * e + h * h)
    r = :math.sqrt(f * f + g * g)
    a1 = :math.atan2(g, f)
    a2 = :math.atan2(h, e)
    {q + r, abs(q - r), (a2 + a1) / 2 * 180 / :math.pi(), q < r, (a2 - a1) / 2}
  end

  @spec points(T.point_list()) :: String.t()
  defp points(points), do: Enum.map_join(points, " ", &point/1)

  @spec point(T.point_tuple()) :: String.t()
  defp point({x, y}), do: number(x) <> "," <> number(y)

  # The shortest text that reads back as exactly the same float.
  @doc false
  @spec number(number()) :: String.t()
  def number(n), do: :erlang.float_to_binary(n * 1.0, [:short])
end
