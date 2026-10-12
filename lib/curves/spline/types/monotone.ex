defmodule Curves.Spline.Type.Monotone do
  @moduledoc ~s"""
  A monotone cubic spline: a smooth curve through data points that never overshoots them. Between
  two knots the curve only ever goes up, only goes down, or stays flat, following the knots. This
  makes it the usual choice for smoothing a line chart.

  The knots are data points: each knot's `x` must be bigger than the one before it (or every one
  smaller), otherwise it raises an `ArgumentError`. The curve is then a function of `x`: it never
  loops back, and never goes above or below the knots either side of it.

  A spline with `n` knots has `n - 1` segments. Within each segment, `x` moves at a steady speed:
  `u = 1.5` is exactly halfway between the second and third knots' `x`.

  ```elixir
  curve = Curves.define_monotone([{0, 2}, {1, 2}, {2, 2}, {3, 8}, {4, 8.5}, {5, 3}, {6, 3}])

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "monotone.svg")
  ```

  | Catmull-Rom, with the same data | Monotone |
  | --- | --- |
  | ![Catmull-Rom overshoots](images/spline_data_catmull_rom.svg) | ![Monotone never overshoots](images/spline_monotone.svg) |

  ## How it is built

  It uses the Fritsch–Carlson method. Each knot gets a slope (how steeply `y` changes with `x`):

  1. The slope at a knot is the average of the slopes of the straight lines either side of it. The
     first and last knots use the slope of their one line.
  2. A knot where the data turns (one line goes up, the other down) or levels out gets slope `0`,
     so the curve doesn't swing past it.
  3. Where two neighbouring slopes are too steep for the line between them, both are scaled down
     until the curve between them can't overshoot.

  Each segment is then the Hermite segment with those slopes, stored as a cubic Bezier curve whose
  control points sit a third and two thirds of the way along in `x`.
  """
  use Curves.Spline.Type

  alias Curves.Types, as: T
  alias Curves.Utils.{Hermite, Vec}

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  @doc false
  @impl true
  def define(points, opts \\ []) do
    knots = Enum.map(points, &Vec.new/1)
    check_x!(knots)

    knots
    |> Enum.map(&[&1])
    |> Curves.define_spline(:monotone, opts)
  end

  # Every knot's x must be bigger than the one before, or every one smaller.
  @spec check_x!(T.point_list()) :: :ok
  defp check_x!(knots) do
    gaps =
      knots |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [{x0, _}, {x1, _}] -> x1 - x0 end)

    one_way? = Enum.all?(gaps, &(&1 > 0)) or Enum.all?(gaps, &(&1 < 0))
    check_one_way!(one_way?, knots)
  end

  @spec check_one_way!(boolean(), T.point_list()) :: :ok
  defp check_one_way!(true, _knots), do: :ok

  defp check_one_way!(false, knots) do
    raise ArgumentError,
          "the knots of a monotone spline must have x always increasing (or always decreasing), " <>
            "so each knot is a data point. Got x values: " <>
            inspect(Enum.map(knots, &elem(&1, 0)), limit: 20) <> ". See Curves.define_monotone/2."
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Replaces the straight segments between the knots with the curve's Bezier segments.
  @doc false
  @impl true
  def map_segments(_segments, %{points: [knot]}), do: [Hermite.stay(knot)]

  def map_segments(_segments, %{points: knots}) do
    lines = knots |> Enum.chunk_every(2, 1, :discard) |> Enum.map(&line/1)
    secants = Enum.map(lines, fn {_p0, _p1, _width, slope} -> slope end)
    slopes = secants |> knot_slopes() |> limit(secants)

    slopes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.zip_with(lines, fn [m0, m1], {p0, p1, width, _slope} ->
      # The tangent per unit of u: x moves `width` across the segment, y moves slope * width.
      Hermite.bezier_segment(p0, {width, m0 * width}, p1, {width, m1 * width})
    end)
  end

  # The straight line between two knots: its ends, its width in x, and its slope.
  @spec line(T.point_list()) :: {T.point_tuple(), T.point_tuple(), float(), float()}
  defp line([{x0, y0} = p0, {x1, y1} = p1]), do: {p0, p1, x1 - x0, (y1 - y0) / (x1 - x0)}

  # Steps 1 and 2 of "How it is built": one slope per knot.
  @spec knot_slopes(nonempty_list(float())) :: nonempty_list(float())
  defp knot_slopes([first | _] = secants) do
    middle =
      secants
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [before, after_] -> middle_slope(before, after_) end)

    [first | middle] ++ [List.last(secants)]
  end

  # The average of the lines either side, or 0 where the data turns or levels out.
  @spec middle_slope(float(), float()) :: float()
  defp middle_slope(before, after_) when before * after_ <= 0, do: 0.0
  defp middle_slope(before, after_), do: (before + after_) / 2

  # Step 3 of "How it is built", one line at a time from the start. Scaling a slope down can only
  # make the next line safer, so one pass is enough.
  @spec limit(list(float()), list(float())) :: list(float())
  defp limit([m0, m1 | slopes], [secant | secants]) do
    {m0, m1} = limit_pair(m0, m1, secant)
    [m0 | limit([m1 | slopes], secants)]
  end

  defp limit(slopes, []), do: slopes

  # A flat line already has both slopes at 0 (step 2).
  @spec limit_pair(float(), float(), float()) :: {float(), float()}
  defp limit_pair(m0, m1, secant) when secant == 0.0, do: {m0, m1}

  defp limit_pair(m0, m1, secant) do
    a = m0 / secant
    b = m1 / secant
    shrink(m0, m1, a * a + b * b)
  end

  # Slopes whose ratios to the line's slope lie outside a circle of radius 3 can overshoot,
  # so both are scaled back onto that circle.
  @spec shrink(float(), float(), float()) :: {float(), float()}
  defp shrink(m0, m1, size) when size > 9.0 do
    scale = 3 / :math.sqrt(size)
    {m0 * scale, m1 * scale}
  end

  defp shrink(m0, m1, _size), do: {m0, m1}
end
