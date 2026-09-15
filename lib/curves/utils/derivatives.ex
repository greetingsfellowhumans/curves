defmodule Curves.Utils.Derivatives do
  alias Curves.Utils.{Point}
  @moduledoc false
  @small_num 0.001

  @doc ~s"""
  Given a point on a curve, find the derivative
  """
  def get_derivative(curve, t, format) do
    coord = case t do
      0 -> 0.0
      _ -> t - @small_num
    end
    {x0, y0} = Curves.solve_spline!(curve, t)
    {x1, y1} = Curves.solve_spline!(curve, coord)
    slope = case {y1 - y0, x1 - x0} do
      {_, +0.0} -> {1_000_000, 1}
      {y, x} -> {y, x}
    end

    case format do
      :tuple -> slope
      :point -> Point.new_point(slope)
    end
  end

  @doc """
  Get the power_series based on the target derivative.
  This can be plugged directly into the matrix form calculation

  ## Examples
      iex> get_power_series(0.5, 0, :asc)
      Nx.tensor([1, 0.5, 0.25, 0.125])
      iex> get_power_series(0.5, 0, :desc)
      Nx.tensor([0.125, 0.25, 0.5, 1])
  """
  @spec get_power_series(t :: float(), derivative :: integer(), dir :: :asc | :desc) ::
          Nx.Tensor.t()
  def get_power_series(t, derivative, dir) do
    d =
      case derivative do
        # position
        0 -> [1, t, t ** 2, t ** 3]
        # velocity. where the velocity at the end of the first curve must equal that of the start of the next curve
        1 -> [0, 1, 2 * t, 3 * t ** 2]
        # acceleration
        2 -> [0, 0, 2, 6 * t]
        # jolt
        3 -> [0, 0, 0, 6]
      end

    case dir do
      :asc -> Nx.tensor(d)
      :desc -> Nx.tensor(Enum.reverse(d))
    end
  end



  def apply_derivatives(%Curves.Spline.Curve{segments: segments, type: type} = curve) do
    segments = case type do
      :bezier_spline -> curve.segments

      _ ->
        Nx.to_list(segments)
          |> Enum.with_index()
          |> curve.mod.map_segments(curve)
        #  |> Enum.map(fn {segment_list, segment_idx} ->
        #    curve.mod.map_segments(curve, segment_list, 1.0 * segment_idx)
        #  end)
          |> Nx.tensor(names: [:segment, :dimension, :point], type: Nx.type(segments))
    end
    %{curve | segments: segments}
  end

  #defp apply_derivatives_to_segment({[[x0, x1, x2, x3], [y0, y1, y2, y3]], segment_idx}, %{type: :hermite} = curve, [d0, d1, d2, d3]) do
  #  u = segment_idx * 1.0
  #  {dx, dy} = get_derivative(curve, u, :tuple)
  #  {dx1, dy1} = get_derivative(curve, u + 1, :tuple)

  #  #{x0, y0} = {x0, y0}
  #  #{x1, y1} = {dx, dy}
  #  #{x2, y2} = {x3, y3}
  #  #{x3, y3} = {dx1, dy1}
  #  [
  #    [x0, x0 + dx / 3, x3 - dx1 / 3, x3],
  #    [y0, y0 + dy / 3, y3 - dy1 / 3, y3]
  #  ]
  #end
  #defp apply_derivatives_to_segment({[[x0, x1, x2, x3], [y0, y1, y2, y3]], segment_idx}, curve, [d0, d1, d2, d3]) do
  #  u = segment_idx * 1.0
  #  {x0, y0} = case d0 do
  #    0 -> {x0, y0}
  #    1 -> get_derivative(curve, u, :tuple)
  #  end
  #  {x1, y1} = case d1 do
  #    0 -> {x1, y1}
  #    1 -> get_derivative(curve, u, :tuple)
  #  end
  #  {x2, y2} = case d2 do
  #    0 -> {x2, y2}
  #    1 -> get_derivative(curve, u + 1, :tuple)
  #  end
  #  {x3, y3} = case d3 do
  #    0 -> {x3, y3}
  #    1 -> {x3, y3} #get_derivative(curve, u + 1, :tuple)
  #  end
  #  [
  #    [x0, x1, x2, x3],
  #    [y0, y1, y2, y3]
  #  ]
  #end
end
