defmodule Curves.Spline.TypeIndex do
  @moduledoc false
  alias Curves.Spline.Type, as: T

  @all %{
    bezier_spline: T.BezierSpline,
    b_spline: T.BSpline,
    catmull_rom: T.CatmullRom,
    hermite: T.Hermite
  }

  @spec list() :: list(atom())
  def list(), do: Map.keys(@all)

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
  # @moduledoc ~s"""
  # Turns a module into a spline type.

  # ```elixir
  # defmodule My.Spline do
  #  use Curves.Spline.Type,
  #    derivative: 0
  # end
  # ```
  # """
  @moduledoc false
  alias Curves.TensorTypes, as: TensorT

  @callback power_series(t :: float()) :: TensorT.power_series()
  @callback blending_function() :: struct()
  @callback point_count() :: integer()

  @doc ~s"""
  Can be used to rearange the points in a segment. Apply derivatives here.

  ```elixir
  @impl true
  def map_segments(all_segments, curve) do
    Enum.map(all_segments, fn {[[x0, x1, x2, x3], [y0, y1, y2, y3]], _segment_idx} ->
      [
        [x0, x1, x2, x3],
        [y0, y1, y2, y3]
      ]
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

  @doc ~s"""
  Shortcut for getting a tuple representing the derivative of a point on the curve.
  """
  @spec d(Curves.Spline.Curve.t(), number()) :: {number(), number()}
  def d(curve, u) do
    Curves.Utils.Derivatives.get_derivative(curve, u, :tuple)
  end

  defmacro __using__(opts) do
    quote do
      import Nx, only: :sigils
      import Curves.Spline.Type, only: [d: 2]
      @behaviour Curves.Spline.Type
      @derivative Keyword.get(unquote(opts), :derivative, 0)

      @doc false
      @override_segment_parsing Keyword.get(unquote(opts), :override_segment_parsing, false)
      @spec override_segment_parsing() :: boolean()
      def override_segment_parsing(), do: @override_segment_parsing

      @doc false
      @impl true
      def power_series(t), do: Curves.Formula.build_power_series(t, @derivative)
      defoverridable power_series: 1

      @doc false
      @impl true
      def map_segments(segment_list, _curve), do: Enum.map(segment_list, fn {li, _idx} -> li end)
      defoverridable map_segments: 2
    end
  end
end
