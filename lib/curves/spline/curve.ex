defmodule Curves.Spline.Curve do
  @moduledoc ~s"""
  This module is meant to only be used internally. You are probably looking for `Curves.define_spline/2` or `Curves.solve/3`
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
    segments: list(),
    type: atom(),
    mod: module(),
    xmax: T.coord(),
    xmin: T.coord(),
    ymax: T.coord(),
    ymin: T.coord(),
    mode: :edit | :run,
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
      origin: Point.new_point({originx, originy}, opts),
      opts: opts
    })

    #Curves.Utils.Derivatives.apply_derivatives(bezier_spline, mod.point_derivatives())
    Curves.Utils.Derivatives.apply_derivatives(bezier_spline)
  end


  defp to_points(segments, opts) do
    List.flatten(segments)
      |> Points.new_points(opts)
  end


  @doc false
  def solve(curve, t), do: solve(curve, t, [])

  @doc false
  def solve(%__MODULE__{segments: _segments, mod: mod, origin: origin, opts: curve_opts} = curve, u, opts) when is_float(u) do
    opts = 
      curve_opts
      |> Keyword.merge(opts)
      |> Curves.Utils.Opts.merge_opts()

    {segment, t} = Segment.split_u(curve, u)
    points = Nx.add(segment, origin)

    tuple = Curves.Formula.run(mod, points, t, opts)
            |> Point.to_tuple()

    {:ok, force_percent(curve, tuple, opts)}

    #case type do
    #  :cubic_bezier -> {:ok, Curves.Formula.run(Curves.Formula.CubicBezier, points, t, opts) |> Point.to_tuple()}
    #  :hermite -> {:ok, Curves.Formula.run(Curves.Formula.Hermite, points, t, opts) |> Point.to_tuple()}
    #  :b_spline -> {:ok, Curves.Formula.run(Curves.Formula.BSpline, points, t, opts) |> Point.to_tuple()}
    #  :bezier_spline -> {:ok, Curves.Formula.run(Curves.Formula.BezierSpline, points, t, opts) |> Point.to_tuple()}
    #  #:b_spline -> {:ok, Curves.Formula.run(Curves.Formula.BSpline, points, t, opts) |> Point.to_tuple()}
    #  _ -> {:error, "UnKnown type :#{type}"}
    #end
    #  |> case do
    #    {:ok, point} -> {:ok, force_percent(curve, point, opts)}
    #    err -> err
    #  end
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

