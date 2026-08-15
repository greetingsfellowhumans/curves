defmodule Curves.Utils.Points do
  @moduledoc false
  alias Curves.Utils.{Coord, Point}

  defguard is_points(p)
           when is_struct(p, Nx.Tensor) and elem(p.shape, 0) == 2 and elem(p.shape, 1) >= 0

  _comment = ~s"""
  ## Examples
      iex> points = new_points([  {1, 10}, {2, 20}, {3, 30}, {4, 40}  ])
      iex> Nx.shape(points)
      {2, 4}
      iex> points
      #Nx.Tensor<
        f16[dimension: 2][point: 4]
        [
          [1.0, 2.0, 3.0, 4.0],
          [10.0, 20.0, 30.0, 40.0]
        ]
      >
  """

  def new_points(coords), do: new_points(coords, [])

  def new_points(points, _opts) when is_points(points), do: points

  def new_points(coords, opts) do
    opts = Curves.Utils.Opts.merge_opts(opts)

    topts = [
      names: [:dimension, :point],
      type: {:f, opts[:float_dtype]}
    ]

    xs = Coord.filter_x(coords)
    ys = Coord.filter_y(coords)
    Nx.tensor([xs, ys], topts)
  end

  _comment = ~s"""
  ## Examples
      iex> points = new_points([  {1, 10}, {2, 20}, {3, 30}, {4, 40}  ])
      iex> tuple_at(points, 2)
      {3.0, 30.0}
  """

  def tuple_at(points, index) do
    p = points[point: index]
    # {Nx.to_number(p[dimension: 0]), Nx.to_number(p[dimension: 1])}
    Point.to_tuple(p)
  end

  _comment = ~s"""
  ## Examples
      iex> points = new_points([  {1, 10}, {2, 20}, {3, 30}, {4, 40}  ])
      iex> point_at(points, 2)
      Curves.Utils.Point.new_point({3, 30})
  """

  def point_at(points, index) do
    p = points[point: index]
    Nx.reshape(p, {2, 1}, names: [:dimension, :point])
  end

  _comment = ~s"""
  ## Examples
      iex> points = new_points([  {1, 10}, {2, 20}, {3, 30}, {4, 40}  ])
      iex> put_point(points, {5, 50})
      #Nx.Tensor<
        f16[dimension: 2][point: 5]
        [
          [1.0, 2.0, 3.0, 4.0, 5.0],
          [10.0, 20.0, 30.0, 40.0, 50.0]
        ]
      >
  """

  def put_point(points, coords), do: put_point(points, coords, [])

  def put_point(points, new_point, _opts) when is_struct(new_point, Nx.Tensor) do
    {2, size} = Nx.shape(points)

    Nx.pad(points, 0.0, [{0, 0, 0}, {0, 1, 0}])
    |> Nx.put_slice([0, size], new_point)
  end

  def put_point(points, coords, opts) do
    new_point = Curves.Utils.Point.new_point(coords, opts)
    put_point(points, new_point, opts)
  end
end
