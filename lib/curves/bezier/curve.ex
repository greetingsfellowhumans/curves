defmodule Curves.Bezier.Curve do
  @moduledoc false
  alias Curves.Utils.{Point, Points}
  alias Curves.Bezier.{Linear, Quadratic}
  alias Curves.Bezier.Predefined

  defstruct [
    :points,
    :ids,
    mode: :edit,
    origin: Nx.tensor([0.0, 0.0])
  ]

  @typedoc ~s"""
  As this library is a WIP, most of these fields are not actually being used.
  """
  @type t :: %__MODULE__{
    points: Nx.Tensor.t(),
    ids: list(),
    mode: :edit | :run,
    origin: Nx.Tensor.t()
  }

  def define(points, opts \\ []) do
    {originx, originy} = Keyword.get(opts, :origin, {0.0, 0.0})
    points = case points do
      k when is_atom(k) -> Predefined.get(k, opts)
      _ -> points
    end

    struct(__MODULE__, %{
      points: Points.new_points(points, opts),
      origin: Point.new_point({originx, originy}, opts)
    })
  end

  def solve(curve, t), do: solve(curve, t, [])

  def solve(%__MODULE__{points: points, origin: origin}, t, opts)
      when is_number(t) do
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
  end

  def solve!(curve, t), do: solve!(curve, t, [])

  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, msg} when is_binary(msg) -> raise msg
    end
  end

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
  def take!(curve, n, opts \\ []) do
    {:ok, points} = take(curve, n, opts)
    points
  end
end
