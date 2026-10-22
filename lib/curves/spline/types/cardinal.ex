defmodule Curves.Spline.Type.Cardinal do
  @moduledoc ~s"""
  A cardinal spline: a Catmull-Rom spline with a `:tension` option that sets how tightly the curve
  bends at each knot.

  You only give the knots, and the curve passes through every one of them. At each knot the curve
  heads in the direction from the knot before it to the knot after it. `:tension` sets how fast:

  | `:tension` | The curve... |
  | --- | --- |
  | `0.0` (the default) | is exactly a `Curves.Spline.Type.CatmullRom` spline |
  | between `0.0` and `1.0` | bends more tightly at each knot, with straighter lines between them |
  | `1.0` | stops at every knot: straight lines that slow down at each knot |
  | below `0.0` | swings wider around each knot |

  A spline with `n` knots has `n - 1` segments, like Catmull-Rom.

  ```elixir
  curve = Curves.define_cardinal([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}], tension: 0.5)

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "cardinal.svg")
  ```

  ![Cardinal spline with tension 0.5](images/spline_cardinal.svg)

  ## How it is built

  The tangent at each knot is `(1 - tension) * (next_knot - previous_knot) / 2`. The first and last
  knots have no knot on one side, so the curve leaves the start heading straight for the second
  knot, and arrives at the end from the second-to-last one (the same as Catmull-Rom). Each segment
  is then the Hermite segment between two knots, stored as a cubic Bezier curve.
  """
  use Curves.Spline.Type

  alias Curves.Utils.{Errors, Hermite, Opts, Vec}

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  @doc false
  @impl true
  def define(points, opts \\ []) do
    opts = Opts.put_numbers!(opts, tension: 0.0)

    points
    |> Errors.check_points!()
    |> Enum.map(&[&1])
    |> Curves.define_spline(:cardinal, opts)
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Replaces the straight segments between the knots with the curve's Bezier segments.
  @doc false
  @impl true
  def map_segments(_segments, %{points: [knot]}), do: [Hermite.stay(knot)]

  def map_segments(_segments, %{points: knots, opts: opts}) do
    speed = (1 - Keyword.get(opts, :tension, 0.0)) / 2

    tangents =
      knots
      |> Hermite.neighbours()
      |> Enum.map(fn {previous, _knot, next} ->
        Vec.scale(Vec.subtract(next, previous), speed)
      end)

    knots
    |> Hermite.same_both_sides(tangents)
    |> Hermite.bezier_segments()
  end
end
