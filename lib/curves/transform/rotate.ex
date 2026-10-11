defmodule Curves.Transform.Rotate do
  @moduledoc false
  alias Curves.Utils.TensorTypes, as: TensorT
  alias Curves.Utils.Types, as: T

  # The 2D matrix that rotates points counter-clockwise by `radians` around {0, 0}.
  @spec rotation_matrix(number()) :: TensorT.rotation_matrix()
  def rotation_matrix(radians) do
    cos = Nx.cos(radians) |> Nx.to_number()
    sin = Nx.sin(radians) |> Nx.to_number()
    neg_sin = Nx.sin(radians) |> Nx.negate() |> Nx.to_number()

    Nx.tensor(
      [
        [cos, neg_sin],
        [sin, cos]
      ],
      names: [:dimension, :point]
    )
  end

  # Rotates a point, points or segments counter-clockwise around `origin`. The result has the same shape.
  @spec rotate_points(p, number(), TensorT.point()) :: p
        when p: TensorT.point() | TensorT.points() | TensorT.cubic_segments()
  def rotate_points(point, radians, origin) do
    matrix = rotation_matrix(radians)
    rotate_points(point, radians, origin, matrix)
  end

  # Same, with the matrix already built, so segments can share one matrix instead of rebuilding it each time.
  @spec rotate_points(p, number(), TensorT.point(), TensorT.rotation_matrix()) :: p
        when p: TensorT.point() | TensorT.points() | TensorT.cubic_segments()
  def rotate_points(point, radians, origin, matrix) do
    case Nx.shape(point) do
      {size, _dimention, _point} ->
        for i <- 0..(size - 1) do
          point[i]
          |> rotate_points(radians, origin, matrix)
        end
        |> Nx.stack()
        |> Nx.rename([:segment, :dimension, :point])

      {_dimention, _point} ->
        point = Nx.subtract(point, origin)

        Nx.dot(matrix, point)
        |> Nx.add(origin)
    end
  end

  # Set (or add to, below) the curve's rotation field, in radians. The points are rotated later, in compress.
  @spec set_rotation(T.curve_struct(), number()) :: T.curve_struct()
  def set_rotation(curve, deg) do
    transform(curve, fn _ -> degrees_to_radians(deg) end)
  end

  @spec inc_rotation(T.curve_struct(), number()) :: T.curve_struct()
  def inc_rotation(curve, amount) do
    transform(curve, fn old -> old + degrees_to_radians(amount) end)
  end

  @spec transform(T.curve_struct(), (float() -> float())) :: T.curve_struct()
  defp transform(curve, cb) do
    Map.update!(curve, :rotation, cb)
  end

  @spec degrees_to_radians(number()) :: float()
  def degrees_to_radians(deg) do
    Nx.divide(Nx.Constants.pi(), 180)
    |> Nx.multiply(deg)
    |> Nx.to_number()
  end
end
