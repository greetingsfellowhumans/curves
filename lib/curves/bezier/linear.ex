defmodule Curves.Bezier.Linear do
  @moduledoc false
  import Nx.Defn

  defn get_linear_interpolation_point(points, t) do
    points[point: 0] + (points[point: 1] - points[point: 0]) * t
  end

  defn get_linear_interpolation_point(start_point, end_point, t) do
    start_point + (end_point - start_point) * t
  end
end
