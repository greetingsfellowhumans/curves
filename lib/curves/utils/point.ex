defmodule Curves.Utils.Point do
  @moduledoc false
  alias Curves.TensorTypes, as: TensorT
  alias Curves.Types, as: T

  _comment = ~s"""
  stores every point as a {2, 1} tensor.
  A group of many points would be a {2, n} tensor.
  """

  defguard is_point(p) when is_struct(p, Nx.Tensor) and p.shape == {2, 1}
  defguard is_n2(p) when p.shape == {2}

  _comment = ~s"""
  Given 2d coordinates, returns a tensor of shape {2, 1} to represent the point in space.

  ## Examples
      iex> new_point({9, 512})
      #Nx.Tensor<
        f16[dimension: 2][point: 1]
        [
          [9.0],
          [512.0]
        ]
      >
  """

  @spec new_point(T.point_tuple() | [T.coord()]) :: TensorT.point()
  def new_point(coords), do: new_point(coords, [])

  @spec new_point(T.point_tuple() | [T.coord()], T.opts()) :: TensorT.point()
  def new_point({x, y}, opts), do: new_point(x, y, opts)
  def new_point([x, y], opts), do: new_point(x, y, opts)

  # The tensor's float type comes from the :float_dtype option (or app config).
  @spec new_point(T.coord(), T.coord(), T.opts()) :: TensorT.point()
  def new_point(x, y, opts) do
    opts = Curves.Utils.Opts.merge_opts(opts)

    topts = [
      names: [:dimension, :point],
      type: {:f, opts[:float_dtype]}
    ]

    Nx.tensor(
      [
        [x],
        [y]
      ],
      topts
    )
  end

  @spec get_x(TensorT.point()) :: float()
  def get_x(p) do
    p[dimension: 0, point: 0]
    |> Nx.to_number()
  end

  @spec get_y(TensorT.point()) :: float()
  def get_y(p) do
    p[dimension: 1, point: 0]
    |> Nx.to_number()
  end

  # Accepts a tuple (returned as-is), a point, or a flat point, so callers don't need to check which.
  @spec to_tuple(T.point_tuple() | TensorT.point() | TensorT.flat_point()) :: T.point_tuple()
  def to_tuple({x, y}), do: {x, y}

  def to_tuple(point) when is_point(point) do
    {Nx.to_number(point[dimension: 0][point: 0]), Nx.to_number(point[dimension: 1][point: 0])}
  end

  def to_tuple(point) when is_n2(point) do
    {Nx.to_number(point[dimension: 0]), Nx.to_number(point[dimension: 1])}
  end
end
