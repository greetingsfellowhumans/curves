defmodule Curves.Utils.Extremes do
  @moduledoc false
  # The points where a curve reaches its lowest and highest x and y: its ends, and each place in
  # between where it turns round. The box around them is exactly the box around the curve, unlike
  # the box around its control points (which can stick out) or around samples (which can miss a tip).
  # Used by Curves.Svg to fit a view box to a drawing.
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Polyline.Curve, as: Polyline
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Types, as: T
  alias Curves.Utils.Errors
  import Curves.Utils.Arc, only: [is_arc: 1]

  @spec points(T.curve_struct()) :: T.point_list()
  def points(curve) do
    cond do
      is_struct(curve, Bezier) -> bezier(Bezier.transformed_points(curve), curve)
      is_struct(curve, Spline) -> curve |> Spline.bezier_segments() |> Enum.flat_map(&segment/1)
      is_struct(curve, Polyline) -> Polyline.transformed_points(curve)
      true -> Errors.raise_not_a_curve(curve)
    end
  end

  # A Bezier curve of up to 4 points is a cubic (a line or quadratic exactly raised to one). With
  # more points it is sampled instead, closely enough for a view box.
  @spec bezier(T.point_list(), T.curve_struct()) :: T.point_list()
  defp bezier([_p0] = points, _curve), do: points
  defp bezier([_p0, _p1] = points, _curve), do: points

  defp bezier([p0, c, p1], _curve),
    do: cubic([p0, towards(p0, c, 2 / 3), towards(p1, c, 2 / 3), p1])

  defp bezier([_p0, _c0, _c1, _p1] = points, _curve), do: cubic(points)

  defp bezier(_points, curve), do: [Curves.solve!(curve, 0.0) | Curves.take!(curve, 1000)]

  @spec segment(list() | tuple()) :: T.point_list()
  defp segment(arc) when is_arc(arc), do: arc_points(arc)
  defp segment(cubic), do: cubic(cubic)

  # A cubic's ends, and where its x or y turns round: where that coordinate's derivative,
  # a t^2 + b t + c (divided by 3), is zero, for t between 0 and 1.
  @spec cubic(T.point_list()) :: T.point_list()
  defp cubic([{x0, y0} = p0, {x1, y1}, {x2, y2}, {x3, y3}] = points) do
    turns =
      for {v0, v1, v2, v3} <- [{x0, x1, x2, x3}, {y0, y1, y2, y3}],
          t <- roots(-v0 + 3 * v1 - 3 * v2 + v3, 2 * (v0 - 2 * v1 + v2), v1 - v0),
          t > 0 and t < 1,
          do: at(points, t)

    [p0, List.last(points) | turns]
  end

  # The real roots of a t^2 + b t + c. A tiny `a` (next to b and c) is a straight line's rounding
  # error, so then it is solved as b t + c.
  @spec roots(float(), float(), float()) :: list(float())
  defp roots(a, b, c), do: roots(a, b, c, abs(a) <= 1.0e-12 * max(abs(b), abs(c)))

  @spec roots(float(), float(), float(), boolean()) :: list(float())
  defp roots(_a, b, c, true = _linear) when b != 0, do: [-c / b]
  defp roots(_a, _b, _c, true = _linear), do: []
  defp roots(a, b, c, false), do: square_roots(a, b, b * b - 4 * a * c)

  @spec square_roots(float(), float(), float()) :: list(float())
  defp square_roots(_a, _b, discriminant) when discriminant < 0, do: []

  defp square_roots(a, b, discriminant) do
    root = :math.sqrt(discriminant)
    [(-b + root) / (2 * a), (-b - root) / (2 * a)]
  end

  # The point t of the way along a cubic.
  @spec at(T.point_list(), float()) :: T.point_tuple()
  defp at([{x0, y0}, {x1, y1}, {x2, y2}, {x3, y3}], t) do
    s = 1 - t
    {a, b, c, d} = {s * s * s, 3 * s * s * t, 3 * s * t * t, t * t * t}
    {a * x0 + b * x1 + c * x2 + d * x3, a * y0 + b * y1 + c * y2 + d * y3}
  end

  @spec towards(T.point_tuple(), T.point_tuple(), float()) :: T.point_tuple()
  defp towards({x0, y0}, {x1, y1}, fraction),
    do: {x0 + (x1 - x0) * fraction, y0 + (y1 - y0) * fraction}

  # An arc's ends, and where its x or y turns round. The arc is c + u cos(theta) + v sin(theta),
  # so x turns round where -ux sin(theta) + vx cos(theta) = 0: at atan2(vx, ux), and every half turn
  # from there. The same goes for y.
  @spec arc_points(tuple()) :: T.point_list()
  defp arc_points({:arc, {cx, cy} = c, {ax, ay}, {bx, by}, from, to, start, finish}) do
    {ux, uy, vx, vy} = {ax - cx, ay - cy, bx - cx, by - cy}
    {low, high} = Enum.min_max([from, to])

    turns =
      for first <- [:math.atan2(vx, ux), :math.atan2(vy, uy)],
          k <- ceil((low - first) / :math.pi())..floor((high - first) / :math.pi())//1,
          theta = first + k * :math.pi(),
          theta > low and theta < high,
          do: arc_point(c, {ux, uy}, {vx, vy}, theta)

    [start, finish | turns]
  end

  @spec arc_point(T.point_tuple(), T.point_tuple(), T.point_tuple(), float()) :: T.point_tuple()
  defp arc_point({cx, cy}, {ux, uy}, {vx, vy}, theta) do
    {cos, sin} = {:math.cos(theta), :math.sin(theta)}
    {cx + ux * cos + vx * sin, cy + uy * cos + vy * sin}
  end
end
