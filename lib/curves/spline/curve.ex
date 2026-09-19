defmodule Curves.Spline.Curve do
  @moduledoc ~s"""
  Struct representing a spline
  """
  alias Curves.Utils.{Point, Points, Segment}
  alias Curves.Utils.Types, as: T
  alias Curves.Bezier.Predefined

  defstruct [
    :points,
    :segments,
    :type,
    :mod,
    :xmax,
    :xmin,
    :ymax,
    :ymin,
    :max_u,
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
  | `:origin` 	| the origin of the graph.                       	|
  | `:opts`   	| The keyword list of options                    	|
  """
  @type t :: %__MODULE__{
    points: Nx.Tensor.t(),
    segments: list(),
    max_u: float(),
    type: atom(),
    mod: module(),
    xmax: T.coord(),
    xmin: T.coord(),
    ymax: T.coord(),
    ymin: T.coord(),
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
    bezier_spline = struct(__MODULE__, %{
      type: spline_type,
      mod: mod,
      points: points,
      segments: segments,
      ymin: Nx.reduce_min(points[dimension: 1]) |> Nx.to_number(),
      ymax: Nx.reduce_max(points[dimension: 1]) |> Nx.to_number(),
      xmin: Nx.reduce_min(points[dimension: 0]) |> Nx.to_number(),
      xmax: Nx.reduce_max(points[dimension: 0]) |> Nx.to_number(),
      max_u: get_max_u(segments),
      origin: Point.new_point({originx, originy}, opts),
      opts: opts
    })

    Curves.Utils.Derivatives.apply_derivatives(bezier_spline)
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
  def solve(%__MODULE__{max_u: max, segments: _segments, mod: mod, origin: origin, opts: curve_opts} = curve, u, opts) when is_float(u) do
    cond do
      (u > max or u < 0.0) -> {:error, :out_of_bounds}
      true ->
        opts = 
          curve_opts
          |> Keyword.merge(opts)
          |> Curves.Utils.Opts.merge_opts()

        {segment, t} = Segment.split_u(curve, u)
        points = Nx.add(segment, origin)

        tuple = Curves.Formula.run(mod, points, t, opts)
                |> Point.to_tuple()

        {:ok, force_percent(curve, tuple, opts)}
    end
  end

  @doc false
  def solve!(curve, t), do: solve!(curve, t, [])

  @doc false
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, :out_of_bounds} -> raise Curves.Exceptions.OutOfBoundU, max: curve.max_u, u: t
    end
  end

  @doc false
  def take(%{segments: segments} = curve, n, opts \\ []) do
    seg_count = Nx.axis_size(segments, :segment)
    step_size = seg_count / n

    Enum.reduce_while(1..n, [], fn step, acc ->
      i = step * step_size
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
    {:ok, points} = take(curve, n, opts)
    points
  end

  defp to_perc(curve, coord, dimension) when is_float(coord) do
    {min, max} = case dimension do
      :x -> {curve.xmin, curve.xmax}
      :y -> {curve.ymin, curve.ymax}
    end
    denominator = max - min
    if denominator == 0, do: max, else: (coord - min) / denominator
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

