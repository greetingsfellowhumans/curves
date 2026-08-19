defmodule Curves.Bezier.Curve do
  @moduledoc ~s"""
  This module is meant to only be used internally. You are probably looking for `Curves.define_bezier/2` or `Curves.solve/3`
  """
  alias Curves.Utils.{Point, Points}
  alias Curves.Utils.Types, as: T
  alias Curves.Bezier.{Linear, Quadratic}
  alias Curves.Bezier.Predefined

  defstruct [
    :points,
    :xmax,
    :xmin,
    :ymax,
    :ymin,
    #:ids,
    mode: :edit,
    opts: [],
    origin: Nx.tensor([0.0, 0.0])
  ]

  @typedoc ~s"""
  | field  	| description                                    	|
  |--------	|------------------------------------------------	|
  | `:points` 	| A tensor representing 2D points                	|
  | `:xmax`   	| the highest x coord in the tensor              	|
  | `:xmin`   	| the lowest x coord in the tensor               	|
  | `:ymin`   	| the lowest y coord in the tensor               	|
  | `:ymax`   	| the highest y coord in the tensor              	|
  | `:mode`   	| Not yet used. Maybe removed in future versions 	|
  | `:origin` 	| the origin of the graph.                       	|
  | `:opts`   	| The keyword list of options                    	|
  """
  @type t :: %__MODULE__{
    points: Nx.Tensor.t(),
    xmax: T.coord(),
    xmin: T.coord(),
    ymax: T.coord(),
    ymin: T.coord(),
    #ids: list(),
    mode: :edit | :run,
    opts: T.opts(),
    origin: Nx.Tensor.t()
  }

  @doc false
  def define(points, opts \\ []) do
    {originx, originy} = Keyword.get(opts, :origin, {0.0, 0.0})
    points = case points do
      k when is_atom(k) -> Predefined.get(k, opts)
      _ -> points
    end
      |> Points.new_points(opts)

    struct(__MODULE__, %{
      points: points,
      ymin: Nx.reduce_min(points[dimension: 1]) |> Nx.to_number(),
      ymax: Nx.reduce_max(points[dimension: 1]) |> Nx.to_number(),
      xmin: Nx.reduce_min(points[dimension: 0]) |> Nx.to_number(),
      xmax: Nx.reduce_max(points[dimension: 0]) |> Nx.to_number(),
      origin: Point.new_point({originx, originy}, opts),
      opts: opts
    })
  end

  @doc false
  def solve(curve, t), do: solve(curve, t, [])

  @doc false
  def solve(%__MODULE__{points: points, origin: origin, opts: curve_opts} = curve, t, opts) when is_number(t) do
    opts = 
      curve_opts
      |> Keyword.merge(opts)
      |> Curves.Utils.Opts.merge_opts()

    {_, size} = Nx.shape(points)
    points = Nx.add(points, origin)

    case size do
      n when n < 2 ->
        {:error, "Cannot solve curve. only #{n} points. need at least 2."}

      2 ->
        {:ok, Linear.get_linear_interpolation_point(points, t) |> Point.to_tuple()}

      3 ->
        {:ok, Quadratic.get_quadratic_point(points, t) |> Point.to_tuple()}

      4 ->
        {:ok, Curves.Formula.run(Curves.Formula.CubicBezier, points, t, opts) |> Point.to_tuple()}

      n when n > 4 ->
        {:ok, Curves.Formula.run(Curves.Formula.CubicBezier, points, t, opts) |> Point.to_tuple()}
    end
      |> case do
        {:ok, point} -> {:ok, force_percent(curve, point, opts)}
        err -> err
      end
  end

  @doc false
  def solve!(curve, t), do: solve!(curve, t, [])

  @doc false
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, msg} when is_binary(msg) -> raise msg
    end
  end

  @doc false
  def take(curve, n, opts \\ []) do
    Enum.reduce_while(1..n, [], fn i, acc ->
      case solve(curve, i * (1 / n), opts) do
        {:ok, point} -> {:cont, [point | acc]}
        {:error, term} -> {:halt, term}
      end
    end)
      |> case do
        li when is_list(li) -> {:ok, Enum.reverse(li)}
        err -> {:error, err}
      end
  end

  @doc false
  def take!(curve, n, opts \\ []) do
    {:ok, points} = take(curve, n, opts)
    points
  end

  defp to_perc(curve, coord, dimension) when is_float(coord) do
    {min, max} = case dimension do
      :x -> {curve.xmin, curve.xmax}
      :y -> {curve.ymin, curve.ymax}
    end
    ( (coord - min) ) / (max - min)
  end

  defp force_percent(curve, point, opts) do
    if !Keyword.get(opts, :force_percent) do
      point
    else
      {x, y} = point
      {to_perc(curve, x, :x), to_perc(curve, y, :y)}
    end
  end
end
