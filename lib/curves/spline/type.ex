defmodule Curves.Spline.TypeIndex do
  @moduledoc false
  alias Curves.Spline.Type, as: T

  @all %{
    bezier_spline: T.BezierSpline,
    b_spline: T.BSpline,
    catmull_rom: T.CatmullRom,
    hermite: T.Hermite
  }

  # Sorted, because Map.keys/1 has no guaranteed order.
  @spec list() :: list(atom())
  def list(), do: @all |> Map.keys() |> Enum.sort()

  # A spline type's module from its key (e.g. :hermite). {:module, mod} passes a custom module through.
  @spec get(atom() | {:module, module()}) :: module()
  def get({:module, mod}), do: mod

  def get(key) do
    case Map.get(@all, key) do
      nil -> raise "Unknown spline_type: #{inspect(key)}"
      mod -> mod
    end
  end
end

defmodule Curves.Spline.Type do
  @moduledoc false
  # Turns a module into a spline type: `use Curves.Spline.Type` (optionally with
  # `override_segment_parsing: true`), then implement the callbacks below.

  # The 4x4 blending matrix: row i holds the weights of the 4 control points for t^i.
  @callback blending_function() :: list(list(number()))
  # A number every coefficient is multiplied by (Catmull-Rom's matrix is defined at twice its size).
  @callback blending_factor() :: number()

  @doc ~s"""
  Can be used to rearrange the points in a segment, e.g. Catmull-Rom swaps in each segment's
  neighbouring knots.

  ```elixir
  @impl true
  def map_segments(all_segments, curve) do
    Enum.map(all_segments, fn {[p0, p1, p2, p3], _segment_idx} ->
      [p0, p1, p2, p3]
    end)
  end
  ```
  """
  @callback map_segments(segments_list :: list(), curve :: Curves.Spline.Curve.t()) :: list()

  @callback define(points :: list(tuple() | list()), opts :: list()) :: Curves.Spline.Curve.t()

  @doc false
  @spec get_mod(atom() | {:module, module()}) :: module()
  defdelegate get_mod(key), to: Curves.Spline.TypeIndex, as: :get

  @doc ~s"""
  Return list of all allowed curve_type keys
  """
  @spec list() :: list(atom())
  defdelegate list(), to: Curves.Spline.TypeIndex

  defmacro __using__(opts) do
    quote do
      @behaviour Curves.Spline.Type

      @doc false
      @override_segment_parsing Keyword.get(unquote(opts), :override_segment_parsing, false)
      @spec override_segment_parsing() :: boolean()
      def override_segment_parsing(), do: @override_segment_parsing

      @doc false
      @impl true
      def blending_factor(), do: 1.0
      defoverridable blending_factor: 0

      @doc false
      @impl true
      def map_segments(segment_list, _curve), do: Enum.map(segment_list, fn {li, _idx} -> li end)
      defoverridable map_segments: 2
    end
  end
end
