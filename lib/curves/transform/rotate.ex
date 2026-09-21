defmodule Curves.Transform.Rotate do
  @moduledoc false

  def rotation_matrix(radians) do
    cos = Nx.cos(radians) |> Nx.to_number()
    sin = Nx.sin(radians) |> Nx.to_number()
    neg_sin = Nx.sin(radians) |> Nx.negate() |> Nx.to_number()


     Nx.tensor([
      [cos, neg_sin],
      [sin, cos]
    ], names: [:dimension, :point])
  end

  def rotate_points(point, radians) do
    matrix = rotation_matrix(radians)
    case Nx.shape(point) do
      {size, _dimention, _point} ->
        for i <- 0..size - 1 do
          point[i] |> rotate_points(radians)
        end
          |> Nx.stack() 
          |> Nx.rename([:segment, :dimension, :point])

      {_dimention, _point} ->
        Nx.dot(matrix, point)
    end
    
  end

  def set_rotation(curve, deg) do
    transform(curve, fn _ -> degrees_to_radians(deg) end)
  end


  def inc_rotation(curve, amount) do
    transform(curve, fn old ->  old + degrees_to_radians(amount) end)
  end


  #@impl true
  defp transform(curve, cb) do
    Map.update!(curve, :rotation, cb)
  end

  def degrees_to_radians(deg) do
    Nx.divide(Nx.Constants.pi(), 180)
    |> Nx.multiply(deg)
    |> Nx.to_number()
  end

end
