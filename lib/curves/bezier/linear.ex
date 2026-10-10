defmodule Curves.Bezier.Linear do
  @moduledoc false
  import Nx.Defn

  # Finds the point a fraction `t` of the way along a straight line between two points.
  #
  # Uses plain Nx calls rather than `defn`, for the same reason as Quadratic:
  # without EXLA, `defn` re-traces on every call, which made this about 3x slower.
  # Because it calls `Nx.tensor/1`, it can't be called from inside a `defn`.
  # The order of operations matches the old `defn`, so results are identical.
  @spec get_linear_interpolation_point(Nx.Tensor.t(), number()) :: Nx.Tensor.t()
  def get_linear_interpolation_point(points, t) do
    start = points[point: 0]
    Nx.add(start, Nx.multiply(Nx.subtract(points[point: 1], start), Nx.tensor(t)))
  end

  # Same as above, but with the two points passed separately.
  # Stays a `defn` because `Quadratic.get_quadratic_bezier_curve_old/4`, also a `defn`, calls it.
  @spec get_linear_interpolation_point(Nx.Tensor.t(), Nx.Tensor.t(), number()) :: Nx.Tensor.t()
  defn get_linear_interpolation_point(start_point, end_point, t) do
    start_point + (end_point - start_point) * t
  end
end
