defmodule Curves.Spline do
  @moduledoc false

  import Curves.Utils.Points
  
  @doc """
  Returns two tensors of points. The hd has exactly 4, the tl has the remainder, but also includes the last point from hd.
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

end
