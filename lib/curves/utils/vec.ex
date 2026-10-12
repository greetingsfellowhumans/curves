defmodule Curves.Utils.Vec do
  @moduledoc false
  # Arithmetic on 2D points stored as `{x, y}` float tuples.
  alias Curves.Types, as: T

  # {x, y} with both values turned into floats, so integer input behaves like float input.
  # Every point a user gives (curve points, :origin, set_position/2, ...) goes through here,
  # so anything else gets a clear error instead of a crash deeper in the maths.
  @spec new(T.point_tuple()) :: T.point_tuple()
  def new({x, y}) when is_number(x) and is_number(y), do: {x * 1.0, y * 1.0}

  def new(other),
    do: raise(ArgumentError, "expected an {x, y} point with numbers, got: #{inspect(other)}")

  @spec add(T.point_tuple(), T.point_tuple()) :: T.point_tuple()
  def add({x, y}, {dx, dy}), do: {x + dx, y + dy}

  @spec subtract(T.point_tuple(), T.point_tuple()) :: T.point_tuple()
  def subtract({x, y}, {dx, dy}), do: {x - dx, y - dy}

  # Multiplies both coordinates by `k`, which scales about {0, 0}. With a {kx, ky} pair, x is
  # multiplied by kx and y by ky, which stretches (or, with a negative, flips) one way more than the other.
  @spec scale(T.point_tuple(), number() | {number(), number()}) :: T.point_tuple()
  def scale({x, y}, {kx, ky}), do: {x * kx, y * ky}
  def scale({x, y}, k), do: {x * k, y * k}

  # Rotates a point counter-clockwise by `radians` around `origin`.
  @spec rotate(T.point_tuple(), number(), T.point_tuple()) :: T.point_tuple()
  def rotate(point, radians, origin) do
    {x, y} = subtract(point, origin)
    cos = :math.cos(radians)
    sin = :math.sin(radians)
    add({x * cos - y * sin, x * sin + y * cos}, origin)
  end

  # The lowest and highest x and y among the points.
  # Example: [{0, 5}, {10, 1}] gives xmin 0, xmax 10, ymin 1, ymax 5.
  @spec bounds(nonempty_list(T.point_tuple())) :: %{
          xmin: number(),
          xmax: number(),
          ymin: number(),
          ymax: number()
        }
  def bounds(points) do
    {xmin, xmax} = points |> Enum.map(&elem(&1, 0)) |> Enum.min_max()
    {ymin, ymax} = points |> Enum.map(&elem(&1, 1)) |> Enum.min_max()
    %{xmin: xmin, xmax: xmax, ymin: ymin, ymax: ymax}
  end
end
