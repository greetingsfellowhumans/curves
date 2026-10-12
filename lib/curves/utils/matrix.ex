defmodule Curves.Utils.Matrix do
  @moduledoc false
  # 2D affine matrices, {a, b, c, d, e, f}, which move {x, y} to {a*x + c*y + e, b*x + d*y + f}
  # (the same as SVG's matrix(a, b, c, d, e, f)).
  alias Curves.Types, as: T

  @type t() :: {float(), float(), float(), float(), float(), float()}

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  @spec identity() :: t()
  def identity(), do: @identity

  # Whether the matrix changes nothing (== so that -0.0 counts as 0.0).
  @spec identity?(t()) :: boolean()
  def identity?(matrix), do: matrix == @identity

  # The matrix that applies `second` first, then `first`.
  @spec multiply(t(), t()) :: t()
  def multiply({a1, b1, c1, d1, e1, f1}, {a2, b2, c2, d2, e2, f2}) do
    {a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2, b1 * c2 + d1 * d2,
     a1 * e2 + c1 * f2 + e1, b1 * e2 + d1 * f2 + f1}
  end

  # Moves a point by the matrix.
  @spec move(t(), T.point_tuple()) :: T.point_tuple()
  def move({a, b, c, d, e, f}, {x, y}), do: {a * x + c * y + e, b * x + d * y + f}

  # The matrix for Curves' own transforms: scale (a number, or {x, y}), then rotate (radians)
  # around {0, 0}, then move by `origin`. The same order as Curves.Transform.
  @spec trs(T.point_tuple(), number() | {number(), number()}, number()) :: t()
  def trs({ox, oy}, {sx, sy}, rotation) do
    cos = :math.cos(rotation)
    sin = :math.sin(rotation)
    {cos * sx, sin * sx, -sin * sy, cos * sy, ox * 1.0, oy * 1.0}
  end

  def trs(origin, scale, rotation), do: trs(origin, {scale, scale}, rotation)
end
