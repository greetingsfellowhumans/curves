defmodule Curves.Bezier.Cubic do
  @moduledoc false
  import Nx.Defn
  # import Curves.Utils

  # @doc ~s"""
  #  Given 4 points, find the point (t)-way between them.
  #
  #  ## Examples
  #      iex> p0 = Nx.tensor([0.1, 0.9])
  #      iex> p1 = Nx.tensor([0.75, 0.1])
  #      iex> c1 = Nx.tensor([0.5, 0.9])
  #      iex> c2 = Nx.tensor([0.5, 0.1])
  #      iex> t = 0.1
  #      iex> expected = Nx.tensor([0.20865, 0.87759984])
  #      iex> get_cubic_bezier_curve(p0, c1, c2, p1, t)
  #      expected
  #      iex> t = 0.3
  #      iex> expected = Nx.tensor([0.36955, 0.7271999])
  #      iex> get_cubic_bezier_curve(p0, c1, c2, p1, t)
  #      expected
  #  """
  #  defn get_cubic_bezier_curve(start_point, control_point1, control_point2, end_point, t) do
  #    tsq = t * t
  #    remainder = 1 - t
  #    rmsq = remainder * remainder
  #    start_multiple = rmsq * remainder
  #    c1_multiple = rmsq * t * 3
  #    c2_multiple = tsq * remainder * 3
  #    end_multiple = tsq * t
  #
  #    start_point * start_multiple + control_point1 * c1_multiple + control_point2 * c2_multiple + end_point * end_multiple
  #  end

  defn get_cubic_point(points, t) do
    tsq = t * t
    remainder = 1 - t
    rmsq = remainder * remainder
    start_multiple = rmsq * remainder
    c1_multiple = rmsq * t * 3
    c2_multiple = tsq * remainder * 3
    end_multiple = tsq * t
    start_point = points[point: 0]
    control_point1 = points[point: 1]
    control_point2 = points[point: 2]
    end_point = points[point: 3]

    raw =
      start_point * start_multiple + control_point1 * c1_multiple + control_point2 * c2_multiple +
        end_point * end_multiple

    Nx.reshape(raw, {2, 1}, names: [:dimension, :point])
  end

  # def get_cubic_bezier_curve(%Curves.Bezier.Curve{points: pn}, t) do
  #  get_cubic_bezier_curve(
  #    get_point(pn, 0),
  #    get_point(pn, 1),
  #    get_point(pn, 2),
  #    get_point(pn, 3),
  #    t
  #  )
  # end

  @doc false
  defn get_cubic_bezier_curve_old(start_point, control_point1, control_point2, end_point, t) do
    q1 =
      Curves.Quadratic.get_quadratic_bezier_curve(start_point, control_point1, control_point2, t)

    q2 = Curves.Quadratic.get_quadratic_bezier_curve(control_point1, control_point2, end_point, t)
    Curves.Linear.get_linear_interpolation_point(q1, q2, t)
  end
end
