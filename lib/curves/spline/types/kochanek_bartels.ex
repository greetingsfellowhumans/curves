defmodule Curves.Spline.Type.KochanekBartels do
  @moduledoc ~s"""
  A Kochanek–Bartels spline, also called a TCB spline: a Catmull-Rom spline with three dials,
  `:tension`, `:continuity` and `:bias`, that change how the curve passes through each knot.
  Animation tools use it for keyframes.

  You only give the knots, and the curve passes through every one of them. Each dial is a number,
  usually between `-1.0` and `1.0`, and `0.0` by default. With all three at `0.0` it is exactly a
  `Curves.Spline.Type.CatmullRom` spline.

  | Option | Below `0.0` | Above `0.0` |
  | --- | --- | --- |
  | `:tension` | rounder, wider bends | tighter bends (`1.0` stops at each knot), like `Curves.Spline.Type.Cardinal` |
  | `:continuity` | sharper corners: at `-1.0` it turns at each knot like a polyline | corners that bulge out: it keeps going past each knot, then turns back |
  | `:bias` | turns early: the curve leans towards the next knot | turns late: the curve overshoots past each knot |

  A spline with `n` knots has `n - 1` segments, like Catmull-Rom. The dials apply to every knot.

  ```elixir
  curve = Curves.define_kochanek_bartels([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}], bias: 0.5)

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "kochanek_bartels.svg")
  ```

  ![Kochanek-Bartels spline with bias 0.5](images/spline_kochanek_bartels.svg)

  ## How it is built

  Unlike the other splines, the curve can arrive at a knot with one tangent and leave it with
  another (that is how `:continuity` makes corners). With `t`, `c` and `b` for the three dials, and
  the knot `p` between `previous` and `next`:

  ```text
  leaving  = (1 - t)(1 + c)(1 + b) / 2 * (p - previous) + (1 - t)(1 - c)(1 - b) / 2 * (next - p)
  arriving = (1 - t)(1 - c)(1 + b) / 2 * (p - previous) + (1 - t)(1 + c)(1 - b) / 2 * (next - p)
  ```

  The first and last knots have no knot on one side, so they get a made-up one, mirrored through
  the end (the same as Catmull-Rom). Each segment is then the Hermite segment between two knots,
  stored as a cubic Bezier curve.
  """
  use Curves.Spline.Type

  alias Curves.Types, as: T
  alias Curves.Utils.{Errors, Hermite, Opts, Vec}

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  @doc false
  @impl true
  def define(points, opts \\ []) do
    opts = Opts.put_numbers!(opts, tension: 0.0, continuity: 0.0, bias: 0.0)

    points
    |> Errors.check_points!()
    |> Enum.map(&[&1])
    |> Curves.define_spline(:kochanek_bartels, opts)
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Replaces the straight segments between the knots with the curve's Bezier segments.
  @doc false
  @impl true
  def map_segments(_segments, %{points: [knot]}), do: [Hermite.stay(knot)]

  def map_segments(_segments, %{points: knots, opts: opts}) do
    t = Keyword.get(opts, :tension, 0.0)
    c = Keyword.get(opts, :continuity, 0.0)
    b = Keyword.get(opts, :bias, 0.0)

    # How much of the way in (p - previous) and the way out (next - p) each tangent takes.
    leaving = {(1 - t) * (1 + c) * (1 + b) / 2, (1 - t) * (1 - c) * (1 - b) / 2}
    arriving = {(1 - t) * (1 - c) * (1 + b) / 2, (1 - t) * (1 + c) * (1 - b) / 2}

    knots
    |> Hermite.neighbours()
    |> Enum.map(fn {previous, knot, next} ->
      way_in = Vec.subtract(knot, previous)
      way_out = Vec.subtract(next, knot)
      {knot, blend(arriving, way_in, way_out), blend(leaving, way_in, way_out)}
    end)
    |> Hermite.bezier_segments()
  end

  # `weight_in` of the way in plus `weight_out` of the way out.
  @spec blend({float(), float()}, T.point_tuple(), T.point_tuple()) :: T.point_tuple()
  defp blend({weight_in, weight_out}, way_in, way_out),
    do: Vec.add(Vec.scale(way_in, weight_in), Vec.scale(way_out, weight_out))
end
