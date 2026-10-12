defmodule Curves.Utils.Poly do
  @moduledoc false
  # Solves curve segments as polynomials in `t`.
  #
  # A segment is solved as `power_series(t) · M · G`: `[1, t, t², t³]` times a blending matrix `M`
  # times the control points `G`. Grouping the sum by power of `t` gives coefficient points
  # `a_i = Σ_j M[i][j] · G_j`, which only depend on the control points. So they're worked out once
  # (`coefficients/3`), and each solve just evaluates `a0 + t·(a1 + t·(a2 + t·a3))` (`eval/2`).
  alias Curves.Types, as: T

  # Coefficient points for one segment, lowest power of t first, as a tuple for fast access.
  # `factor` scales every coefficient (Catmull-Rom's matrix is defined at twice its size).
  @spec coefficients(list(list(number())), list(T.point_tuple()), number()) :: tuple()
  def coefficients(matrix, points, factor \\ 1.0) do
    matrix
    |> Enum.map(fn row ->
      Enum.zip_reduce(row, points, {0.0, 0.0}, fn m, {x, y}, {ax, ay} ->
        {ax + m * factor * x, ay + m * factor * y}
      end)
    end)
    |> List.to_tuple()
  end

  # Evaluates the coefficients at `t` with Horner's method (highest power first).
  @spec eval(tuple(), number()) :: T.point_tuple()
  def eval({{x0, y0}, {x1, y1}}, t), do: {x0 + t * x1, y0 + t * y1}

  def eval({{x0, y0}, {x1, y1}, {x2, y2}}, t),
    do: {x0 + t * (x1 + t * x2), y0 + t * (y1 + t * y2)}

  def eval({{x0, y0}, {x1, y1}, {x2, y2}, {x3, y3}}, t),
    do: {x0 + t * (x1 + t * (x2 + t * x3)), y0 + t * (y1 + t * (y2 + t * y3))}

  # The cubic Bezier points that make the same curve as the coefficients (the reverse of
  # coefficients/3 with the Bezier matrix): p0 = a0, c0 = a0 + a1/3, c1 = a0 + (2a1 + a2)/3,
  # p1 = a0 + a1 + a2 + a3.
  @spec to_bezier(tuple()) :: list(T.point_tuple())
  def to_bezier({{x0, y0}, {x1, y1}, {x2, y2}, {x3, y3}}) do
    [
      {x0, y0},
      {x0 + x1 / 3, y0 + y1 / 3},
      {x0 + (2 * x1 + x2) / 3, y0 + (2 * y1 + y2) / 3},
      {x0 + x1 + x2 + x3, y0 + y1 + y2 + y3}
    ]
  end
end
