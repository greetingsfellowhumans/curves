defmodule Curves.Bezier.Quadratic do
  @moduledoc false
  alias Curves.TensorTypes, as: TensorT

  # Finds the point a fraction `t` of the way along a 3-point bezier curve.
  #
  # Uses plain Nx calls rather than `defn`: without EXLA, `defn` re-traces the
  # whole expression on every call, which made this about 3x slower.
  # Because it calls `Nx.tensor/1`, it can't be called from inside a `defn`.
  #
  # The order of operations matches the original `defn` exactly. Changing it shifts
  # results by float rounding, which the recorded-value tests will catch.
  @spec get_quadratic_point(TensorT.points(), number()) :: TensorT.point()
  def get_quadratic_point(points, t) do
    # The original `defn` turned a plain number into a tensor this same way
    # (floats -> f32, integers -> s32), so the output stays identical.
    t = Nx.tensor(t)
    remainder = Nx.subtract(1, t)
    start_multiplier = Nx.multiply(remainder, remainder)
    control_multiplier = remainder |> Nx.multiply(t) |> Nx.multiply(2)
    end_multiplier = Nx.multiply(t, t)

    points[point: 0]
    |> Nx.multiply(start_multiplier)
    |> Nx.add(Nx.multiply(points[point: 1], control_multiplier))
    |> Nx.add(Nx.multiply(points[point: 2], end_multiplier))
    |> Nx.reshape({2, 1}, names: [:dimension, :point])
  end
end
