defmodule Curves.Spline.Type.Hermite do
  @moduledoc ~s"""
  A cubic Hermite spline: a smooth curve through every knot, leaving each knot in the direction
  (and with the speed) of the tangent you give it.

  Each point is a list of its knot and its tangent, `[{x, y}, {tx, ty}]`. The tangent is the
  curve's velocity at that knot per unit of `u`: a longer tangent makes the curve leave the knot
  more steeply and bend later. A spline with `n` points has `n - 1` segments.

  ```elixir
  curve = Curves.define_hermite([
    [{0, 0}, {10, 0}],
    [{10, 5}, {0, 10}],
    [{20, 10}, {10, 0}]
  ])

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "hermite.svg")
  ```

  ![Hermite Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/hermite.svg)

  ## How it is built

  A Hermite segment from knot `p0` (tangent `m0`) to knot `p1` (tangent `m1`) is exactly the cubic
  Bezier curve `[p0, p0 + m0 / 3, p1 - m1 / 3, p1]`. So each segment is stored and solved as that
  Bezier curve: the curve stores those Bezier points (the knots plus the two points beside each),
  and `Curves.Svg` draws them as its dots.
  """
  use Curves.Spline.Type,
    override_segment_parsing: true

  alias Curves.Types, as: T
  alias Curves.Utils.{Errors, Vec}

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  @doc false
  @impl true
  def define(points, opts \\ []) do
    points
    |> Errors.check_points!()
    |> Enum.map(&knot_and_tangent/1)
    |> to_bezier_segments()
    |> Curves.define_spline(:hermite, opts)
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Checks one point is [{x, y}, {tx, ty}], and turns it into floats.
  @spec knot_and_tangent(term()) :: {T.point_tuple(), T.point_tuple()}
  defp knot_and_tangent([{_, _} = knot, {_, _} = tangent]), do: {Vec.new(knot), Vec.new(tangent)}

  defp knot_and_tangent(other) do
    raise ArgumentError,
          "each point of a Hermite spline must be [{x, y}, {tangent_x, tangent_y}]. " <>
            "Got: #{inspect(other)}. See Curves.define_hermite/2."
  end

  # One Bezier segment per pair of neighbouring knots: [p0, p0 + m0 / 3, p1 - m1 / 3, p1].
  @spec to_bezier_segments(list({T.point_tuple(), T.point_tuple()})) :: list(T.point_list())
  defp to_bezier_segments(points) when length(points) < 2 do
    raise ArgumentError, "a Hermite spline needs at least 2 points, got #{length(points)}"
  end

  defp to_bezier_segments(points) do
    points
    |> Enum.map(fn {knot, tangent} -> {knot, tangent, tangent} end)
    |> Curves.Utils.Hermite.bezier_segments()
  end
end
