defmodule Curves.Spline.Curve do
  @moduledoc ~s"""
  Struct representing a spline
  """
  alias Curves.Types, as: T
  alias Curves.Utils.{Percent, Poly, Segment, Vec}

  @minimum_u 0.0 - Curves.Utils.Constants.small_number()

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
    origin: {0.0, 0.0}
  ]

  @typedoc ~s"""
  A spline. Its fields are internal and may change in any 1.x release,
  so use the functions in `Curves` (e.g. `Curves.solve/3`, `Curves.max_u/1`) instead of reading them.
  """
  @opaque t :: %__MODULE__{
            points: T.point_list(),
            segments: list(Segment.t()),
            transformations: list(),
            compressed: (u :: float(), opts :: T.opts() -> {:ok, T.point_tuple()}),
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
            origin: T.point_tuple()
          }

  # Each spline type's define/2 prepares `coords` first (e.g. wrapping each point in a list),
  # so the shape of `coords` depends on the type.
  @doc false
  @spec define(list(list(T.point_tuple())), atom(), T.opts()) :: t()
  def define(coords, spline_type, opts \\ []) do
    mod = Curves.Spline.Type.get_mod(spline_type)
    {originx, originy} = Keyword.get(opts, :origin, {0.0, 0.0})

    segments =
      if mod.override_segment_parsing() do
        Enum.map(coords, fn segment -> Enum.map(segment, &Vec.new/1) end)
      else
        Segment.new_segments(coords)
      end

    points = coords |> List.flatten() |> Enum.map(&Vec.new/1)

    # We use an intermediary bezier_spline in order to later calculate derivatives.
    curve =
      struct(
        __MODULE__,
        Map.merge(Vec.bounds(points), %{
          type: spline_type,
          mod: mod,
          points: points,
          segments: segments,
          transformations: [],
          scale: 1.0,
          rotation: 0.0,
          max_u: length(segments) * 1.0,
          origin: Vec.new({originx, originy}),
          opts: opts
        })
      )

    {:ok, compressed} = compress(curve, opts)
    curve = Map.put(curve, :compressed, compressed)
    curve = Curves.Utils.Derivatives.apply_derivatives(curve)

    {:ok, compressed} = compress(curve, opts)
    Map.put(curve, :compressed, compressed)
  end

  @doc false
  @spec compress(__MODULE__.t(), opts :: list()) ::
          {:ok, (u :: float(), opts :: T.opts() -> {:ok, T.point_tuple()})} | {:error, any()}
  def compress(%__MODULE__{mod: mod} = curve, _opts \\ []) do
    curve = Curves.Transform.apply_all_transformations(curve)
    # Bounds of a transformed copy of the original points. `curve.points` itself is never changed.
    bounds =
      Percent.get_bounds_after_transforms(curve, fn ->
        Curves.Transform.transform_points(curve, curve.points)
      end)

    # Each segment's polynomial coefficients, worked out once; a tuple so solving can pick one by index.
    coefficients =
      curve.segments
      |> Enum.map(&Poly.coefficients(mod.blending_function(), &1, mod.blending_factor()))
      |> List.to_tuple()

    {:ok,
     fn u, solve_opts ->
       {index, t} = Segment.split_u(u)
       point = coefficients |> elem(index) |> Poly.eval(t)
       {:ok, Percent.maybe_normalize(bounds, point, solve_opts)}
     end}
  end

  @doc false
  @spec solve(t(), number()) :: {:ok, T.point_tuple()} | {:error, {:out_of_bounds, number()}}
  def solve(curve, t), do: solve(curve, t, [])

  @doc false
  @spec solve(t(), number(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, {:out_of_bounds, number()}}
  def solve(%__MODULE__{} = curve, u, opts) when is_number(u),
    do: solve_resolved(curve, u, resolve_opts(curve, opts))

  # Solves with opts that already went through resolve_opts/2, so take/3 can resolve them
  # once for every point instead of once per point.
  @spec solve_resolved(t(), number(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, {:out_of_bounds, number()}}
  defp solve_resolved(%{max_u: max}, u, _opts) when u > max or u < @minimum_u,
    do: {:error, {:out_of_bounds, u}}

  defp solve_resolved(%{compressed: cb}, u, opts), do: cb.(u * 1.0, opts)

  # Reads :force_percent once per solve or take call (see Opts.put_force_percent/2).
  @spec resolve_opts(t(), T.opts()) :: T.opts()
  defp resolve_opts(curve, opts), do: Curves.Utils.Opts.put_force_percent(curve.opts, opts)

  @doc false
  @spec solve!(t(), number()) :: T.point_tuple()
  def solve!(curve, t), do: solve!(curve, t, [])

  @doc false
  @spec solve!(t(), number(), T.opts()) :: T.point_tuple()
  def solve!(curve, t, opts) do
    case solve(curve, t, opts) do
      {:ok, resp} -> resp
      {:error, {:out_of_bounds, u}} -> raise Curves.Exceptions.OutOfBoundU, max: curve.max_u, u: u
    end
  end

  # n evenly spaced points by u, ending at max_u (u = 0 is not included).
  @doc false
  @spec take(t(), pos_integer(), T.opts()) ::
          {:ok, T.point_list()} | {:error, {:out_of_bounds, number()}}
  def take(%{segments: segments} = curve, n, opts \\ []) do
    seg_count = length(segments)
    opts = resolve_opts(curve, opts)

    Enum.reduce_while(1..n, [], fn step, acc ->
      # Multiply before dividing so the final step lands exactly on seg_count, not 3.0000000000000004.
      i = step * seg_count / n

      case solve_resolved(curve, i, opts) do
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
  @spec take!(t(), pos_integer(), T.opts()) :: T.point_list()
  def take!(curve, n, opts \\ []) do
    case take(curve, n, opts) do
      {:ok, points} -> points
      {:error, {:out_of_bounds, u}} -> raise Curves.Exceptions.OutOfBoundU, max: curve.max_u, u: u
    end
  end
end
