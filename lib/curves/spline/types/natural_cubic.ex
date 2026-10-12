defmodule Curves.Spline.Type.NaturalCubic do
  @moduledoc ~s"""
  A natural cubic spline: the smoothest curve that passes through every knot.

  Catmull-Rom and its relatives only keep the curve's direction smooth at each knot. A natural
  cubic spline also keeps its *bend* (its curvature) smooth, like a `Curves.Spline.Type.BSpline`,
  but unlike a B-spline it still goes through every knot. It is what you get if you bend a thin,
  flexible strip of wood or metal through pins at the knots, which is where the name "spline" comes
  from. At the first and last knots it straightens out, as a free strip would.

  The catch is that every knot affects the whole curve: moving one knot changes every segment a
  little, not just the nearby ones.

  A spline with `n` knots has `n - 1` segments, like Catmull-Rom.

  ```elixir
  curve = Curves.define_natural_cubic([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])

  # Find any point along the curve (u goes from 0.0 to Curves.max_u(curve))...
  Curves.solve!(curve, 1.5)

  # ...or draw the whole curve as an SVG image
  Curves.Svg.save!(curve, "natural_cubic.svg")
  ```

  ![Natural cubic spline](images/spline_natural_cubic.svg)

  ## How it is built

  The tangents `D0 .. Dn-1` at the knots `P0 .. Pn-1` are the ones that make the curve's bend
  continuous at every knot and zero at both ends. They come from solving these equations together
  (each is one row of a tridiagonal system, solved in one pass each way):

  ```text
  2 * D0   + D1                = 3 * (P1 - P0)
  D(i - 1) + 4 * Di + D(i + 1) = 3 * (P(i + 1) - P(i - 1))     for every middle knot
  D(n - 2) + 2 * D(n - 1)      = 3 * (P(n - 1) - P(n - 2))
  ```

  Each segment is then the Hermite segment between two knots, stored as a cubic Bezier curve.
  """
  use Curves.Spline.Type

  alias Curves.Types, as: T
  alias Curves.Utils.{Hermite, Vec}

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  # One row of the system: a * D(i - 1) + b * Di + c * D(i + 1) = r.
  @typep row() :: {float(), float(), float(), T.point_tuple()}

  @doc false
  @impl true
  def define(points, opts \\ []) do
    points
    |> Enum.map(&[&1])
    |> Curves.define_spline(:natural_cubic, opts)
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # Replaces the straight segments between the knots with the curve's Bezier segments.
  @doc false
  @impl true
  def map_segments(_segments, %{points: [knot]}), do: [Hermite.stay(knot)]

  def map_segments(_segments, %{points: knots}) do
    knots
    |> Hermite.same_both_sides(knots |> rows() |> solve())
    |> Hermite.bezier_segments()
  end

  # The rows of the system in "How it is built" above. Needs at least 2 knots.
  @spec rows(T.point_list()) :: list(row())
  defp rows([p0, p1 | _] = knots) do
    [last, second_last | _] = Enum.reverse(knots)

    middle =
      knots
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(fn [before, _knot, after_] -> {1.0, 4.0, 1.0, triple(after_, before)} end)

    [{0.0, 2.0, 1.0, triple(p1, p0)} | middle] ++ [{1.0, 2.0, 0.0, triple(last, second_last)}]
  end

  # 3 * (a - b)
  @spec triple(T.point_tuple(), T.point_tuple()) :: T.point_tuple()
  defp triple(a, b), do: Vec.scale(Vec.subtract(a, b), 3)

  # Solves a tridiagonal system with the Thomas algorithm. The forward pass removes each row's `a`
  # using the row before; the backward pass then works out each D from the one after it. The
  # system is diagonally dominant (each b is bigger than a + c), so this is stable.
  @spec solve(list(row())) :: T.point_list()
  defp solve(rows) do
    rows
    |> forward([], {0.0, {0.0, 0.0}})
    |> backward([], {0.0, 0.0})
  end

  # Each row becomes {c', r'}: Di + c' * D(i + 1) = r'. Built back to front, ready for backward/3.
  @spec forward(list(row()), list({float(), T.point_tuple()}), {float(), T.point_tuple()}) ::
          list({float(), T.point_tuple()})
  defp forward([], acc, _previous), do: acc

  defp forward([{a, b, c, r} | rows], acc, {c_prev, r_prev}) do
    denominator = b - a * c_prev
    row = {c / denominator, Vec.scale(Vec.subtract(r, Vec.scale(r_prev, a)), 1 / denominator)}
    forward(rows, [row | acc], row)
  end

  # Di = r' - c' * D(i + 1), from the last row to the first, so the result comes out in order.
  @spec backward(list({float(), T.point_tuple()}), T.point_list(), T.point_tuple()) ::
          T.point_list()
  defp backward([], acc, _next), do: acc

  defp backward([{c, r} | rows], acc, next) do
    d = Vec.subtract(r, Vec.scale(next, c))
    backward(rows, [d | acc], d)
  end
end
