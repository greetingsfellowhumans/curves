defmodule Curves.Bezier.Quadratic do
  @moduledoc false
  import Nx.Defn
  #  import Curves.Utils.Points

  #  @doc ~s"""
  #  Given 3 points, find the point (t)-way between them.
  #
  #  ## Examples
  #      iex> p0 = Nx.tensor([0.0, 0.0])
  #      iex> p1 = Nx.tensor([5.0, 10.0])
  #      iex> pc = Nx.tensor([10.0, 6.0])
  #      iex> t = 0.5
  #      iex> expected_p2 = Nx.tensor([6.25, 5.5])
  #      iex> get_quadratic_bezier_curve(p0, pc, p1, t)
  #      expected_p2
  #      iex> t = 0.25
  #      iex> expected_p2 = Nx.tensor([4.0625, 2.875])
  #      iex> get_quadratic_bezier_curve(p0, pc, p1, t)
  #      expected_p2
  #  """
  #  defn get_quadratic_bezier_curve(start_point, control_point, end_point, t) do
  #    remainder = 1 - t
  #    start_multiplier = remainder * remainder
  #    control_multiplier = remainder * t * 2
  #    end_multiplier = t * t
  #    start_point * start_multiplier + control_point * control_multiplier + end_point * end_multiplier
  #  end
  defn get_quadratic_point(points, t) do
    remainder = 1 - t
    start_multiplier = remainder * remainder
    control_multiplier = remainder * t * 2
    end_multiplier = t * t

    raw =
      points[point: 0] * start_multiplier + points[point: 1] * control_multiplier +
        points[point: 2] * end_multiplier

    Nx.reshape(raw, {2, 1}, names: [:dimension, :point])
  end

  @deprecated "This works, and it is easy to read, but is slightly less performant"
  defn get_quadratic_bezier_curve_old(start_point, control_point, end_point, t) do
    interpolation_point0 =
      Curves.Bezier.Linear.get_linear_interpolation_point(start_point, control_point, t)

    interpolation_point1 =
      Curves.Bezier.Linear.get_linear_interpolation_point(control_point, end_point, t)

    Curves.Bezier.Linear.get_linear_interpolation_point(
      interpolation_point0,
      interpolation_point1,
      t
    )
  end
end
