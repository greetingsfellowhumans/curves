defmodule Curves.Spline do
  @moduledoc false

  import Curves.Utils.{Points, Numbers}

  @doc """
  Returns two tensors of points. The hd has exactly 4, the tl has the remainder, but also includes (at idx 0) the last point from hd.
  If there are 3 or less points, then no tail is returned. only `[hd]`
  """
  @spec split_points(points :: Nx.Tensor.t()) :: list(Nx.Tensor.t())
  def split_points(points) when is_points(points) do
    {_, size} = Nx.shape(points)

    if size > 4 do
      hd = Nx.slice(points, [0, 0], [2, 4])
      tl = Nx.slice(points, [0, 3], [2, size - 3])
      [hd, tl]
    else
      [points]
    end
  end

  @doc """
  Given a list of segments, of equal length, finds the point for `u`.
  Such that `u` is a float in which the integer part represents the index of th
  """
  def solve(curve, u, opts) when is_struct(curve) do
    {idx, perc} = split_float(u)

    curve.points
    |> Enum.at(idx)
    |> Curves.define_bezier(opts)
    |> Curves.solve!(perc, opts)
  end
end
