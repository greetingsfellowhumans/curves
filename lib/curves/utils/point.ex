defmodule Curves.Utils.Point do
  @moduledoc false

  _comment = ~s"""
  stores every point as a {2, 1} tensor.
  A group of many points would be a {2, n} tensor.
  """

  defguard is_point(p) when p.shape == {2, 1}
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
  def new_point(coords), do: new_point(coords, [])
  def new_point({x, y}, opts), do: new_point(x, y, opts)
  def new_point([x, y], opts), do: new_point(x, y, opts)

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

  def get_x(p) do
    p[dimension: 0, point: 0]
    |> Nx.to_number()
  end

  def get_y(p) do
    p[dimension: 1, point: 0]
    |> Nx.to_number()
  end

  def to_tuple({x, y}), do: {x, y}
  def to_tuple(point) when is_point(point) do
    {Nx.to_number(point[dimension: 0][point: 0]), Nx.to_number(point[dimension: 1][point: 0])}
  end
  def to_tuple(point) when is_n2(point) do
    {Nx.to_number(point[dimension: 0]), Nx.to_number(point[dimension: 1])}
  end
end
