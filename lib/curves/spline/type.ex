defmodule Curves.Spline.TypeIndex do
  alias Curves.Spline.Type, as: T

  @all %{
    bezier_spline: T.BezierSpline,
    hermite: T.Hermite,
  }

  def list(), do: Map.keys(@all)

  def get({:module, mod}), do: mod
  def get(key) do
    case Map.get(@all, key) do
      nil -> raise "Unknown spline_type: #{inspect key}"
      mod -> mod
    end
  end
end


defmodule Curves.Spline.Type do
  @moduledoc ~s"""
  Turns a module into a spline type.

  ```elixir
  defmodule My.Spline do
    use Curves.Spline.Type,
      derivatives: [0, 1, 1, 0]
  end
  ```
  """

  @callback power_series(t :: float()) :: Nx.Tensor.t()
  @callback blending_function() :: struct()
  @callback point_count() :: integer()


  @doc false
  defdelegate get_mod(key), to: Curves.Spline.TypeIndex, as: :get

  @doc ~s"""
  Return list of all allowed curve_type keys
  """
  defdelegate list(), to: Curves.Spline.TypeIndex


  defmacro __using__(opts) do
    quote do
      import Nx, only: :sigils
      @behaviour Curves.Spline.Type
      @derivatives Keyword.get(unquote(opts), :derivatives, [0, 0, 0, 0])
      @derivative  Keyword.get(unquote(opts), :derivative, 0)


      @impl true
      def power_series(t), do: Curves.Formula.build_power_series(t, @derivative)
      defoverridable power_series: 1

      def point_derivatives(), do: @derivatives



    end
  end


end
