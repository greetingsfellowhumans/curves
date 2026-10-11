defmodule Curves.Spline.Curve do
  @moduledoc ~s"""
  Struct representing a spline
  """
  alias Curves.Bezier.Predefined
  alias Curves.Utils.{Percent, Point, Points, Segment}
  alias Curves.Utils.Types, as: T

  @minimum_u (0.0 - Curves.Utils.Constants.small_number())

  defstruct [
    :points,
    :segments,
    :transformations,
    :compressed,
    :type,
    :mod,
    :xmax,
    :xmin,
    :ymax,
    :ymin,
    :max_u,
    :scale,
    :rotation,
    opts: [],
    origin: Nx.tensor([0.0, 0.0])
  ]

  @typedoc ~s"""
  | field  	| description                                    	|
  |--------	|------------------------------------------------	|
  | `:points` 	| The knots and control points the spline is built from, before any transforms. Catmull-Rom and Hermite splines store only their knots. B-splines store Bezier points generated from the ones you give.	|
  | `:xmax`   	| the highest x coord in the tensor, before any transforms	|
  | `:xmin`   	| the lowest x coord in the tensor, before any transforms	|
  | `:ymin`   	| the lowest y coord in the tensor, before any transforms	|
  | `:ymax`   	| the highest y coord in the tensor, before any transforms	|
  | `:max_u`   	| maximum allowable u value.              	|
  | `:scale`   	| multiplier for resizing curve.              	|
  | `:transformations` 	| list of transformations that have been applied |
  | `:rotation` 	| the degrees by which the curve is rotated.   	|
  | `:compressed` 	| A preprocessed function for fast solving |
  | `:origin` 	| the origin of the graph.                       	|
  | `:opts`   	| The keyword list of options                    	|
  """
  @type t :: %__MODULE__{
    points: Nx.Tensor.t(),
    segments: list(),
    transformations: list(),
    compressed: (u :: float(), opts :: T.opts() -> T.point_tuple()),
    max_u: float(),
    type: atom(),
    mod: module(),
    xmax: T.coord(),
    xmin: T.coord(),
    ymax: T.coord(),
    ymin: T.coord(),
    scale: float(),
    rotation: float(),
    opts: T.opts(),
    origin: Nx.Tensor.t()
  }

  @doc false
  def define(coords, spline_type, opts \\ []) do
    mod = Curves.Spline.Type.get_mod(spline_type)
    {originx, originy} = Keyword.get(opts, :origin, {0.0, 0.0})
    coords = case coords do
      k when is_atom(k) -> Predefined.get(k, opts)
      _ -> coords
    end

    segments = if mod.override_segment_parsing() do
      coords
      |> Enum.map(&Points.new_points(&1, opts))
      |> Nx.stack(name: :segment)
    else
      Segment.new_segments(coords, opts)
    end

    points = to_points(coords, opts)

    # We use an intermediary bezier_spline in order to later calculate derivatives.
    curve = struct(__MODULE__, %{
      type: spline_type,
      mod: mod,
      points: points,
      segments: segments,
      transformations: [],
      ymin: Nx.reduce_min(points[dimension: 1]) |> Nx.to_number(),
      ymax: Nx.reduce_max(points[dimension: 1]) |> Nx.to_number(),
      xmin: Nx.reduce_min(points[dimension: 0]) |> Nx.to_number(),
      xmax: Nx.reduce_max(points[dimension: 0]) |> Nx.to_number(),
      scale: 1.0,
      rotation: 0.0,
      max_u: get_max_u(segments),
      origin: Point.new_point({originx, originy}, opts),
      opts: opts
    })

    {:ok, compressed} = compress(curve, opts)
    curve = Map.put(curve, :compressed, compressed)
    curve = Curves.Utils.Derivatives.apply_derivatives(curve)

    {:ok, compressed} = compress(curve, opts)
    Map.put(curve, :compressed, compressed)
  end

  @spec compress(__MODULE__.t(), opts :: list()) ::
          {:ok, (u :: float(), opts :: T.opts() -> {:ok, T.point_tuple()})} | {:error, any()}
  def compress(%__MODULE__{opts: curve_opts, mod: mod} = curve, opts \\ []) do
    opts =
      curve_opts
      |> Keyword.merge(opts)
      |> Curves.Utils.Opts.merge_opts()

    curve = Curves.Transform.apply_all_transformations(curve)
    # Bounds of a transformed copy of the original points. `curve.points` itself is never changed.
    bounds = Percent.get_bounds_after_transforms(curve, fn -> Curves.Transform.transform_points(curve, curve.points) end)

    {:ok, fn u, solve_opts ->
      {points, t} = Segment.split_u(curve, u)
      tuple = Curves.Formula.run(mod, points, t, Keyword.merge(opts, solve_opts))
              |> Point.to_tuple()

      {:ok, Percent.maybe_normalize(bounds, tuple, Keyword.merge(opts, solve_opts))}
    end}
  end

  defp get_max_u(segments) do
    {s, _d, _p} = Nx.shape(segments)
    s * 1.0
  end

  defp to_points(segments, opts) do
    List.flatten(segments)
      |> Points.new_points(opts)
  end

  @doc false
  def solve(curve, t), do: solve(curve, t, [])

  @doc false
  def solve(%__MODULE__{max_u: max}, u, _opts) when is_number(u) and (u > max or u < @minimum_u),
    do: {:error, {:out_of_bounds, u}}
  def solve(%__MODULE__{compressed: cb}, u, opts) when is_number(u), do: cb.(u * 1.0, opts)

  @doc false
  def solve!(curve, t), do: solve!(curve, t, [])

  @doc false
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, {:out_of_bounds, u}} -> raise Curves.Exceptions.OutOfBoundU, max: curve.max_u, u: u
    end
  end

  @doc false
  def take(%{segments: segments} = curve, n, opts \\ []) do
    seg_count = Nx.axis_size(segments, :segment)

    Enum.reduce_while(1..n, [], fn step, acc ->
      # Multiply before dividing so the final step lands exactly on seg_count, not 3.0000000000000004.
      i = step * seg_count / n
      case solve(curve, i, opts) do
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
    case take(curve, n, opts) do
      {:ok, points} -> points
      {:error, {:out_of_bounds, u}} -> raise Curves.Exceptions.OutOfBoundU, max: curve.max_u, u: u
    end
  end
end
