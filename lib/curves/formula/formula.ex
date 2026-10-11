defmodule Curves.Formula do
  @moduledoc false
  alias Curves.TensorTypes, as: TensorT
  alias Curves.Types, as: T

  @callback power_series(t :: float()) :: TensorT.power_series()
  @callback blending_function() :: struct()
  @callback required_opts() :: list()
  @callback point_count() :: integer()

  # Solves one 4-point segment with the matrix form: power_series(t) · blending matrix · points.
  # Callers always pass 4 points: a cubic bezier, or one spline segment.
  @spec run(module(), TensorT.points() | TensorT.cubic_segment(), number(), T.opts()) ::
          TensorT.point()
  def run(mod, points, t, _opts \\ []) do
    mod.power_series(t)
    |> Nx.dot(mod.blending_function())
    |> Nx.multiply(points)
    |> Nx.window_sum({1, mod.point_count()})
  end

  # [1, t, t², t³], or its 1st/2nd/3rd derivative. 0.5 is a half-weighted series.
  @spec build_power_series(number(), 0..3 | float()) :: TensorT.power_series()
  def build_power_series(t, derivative \\ 0) do
    case derivative do
      0.5 ->
        [1, t, t ** 2, t ** 3]
        |> Nx.tensor()
        |> Nx.divide(2)

      0 ->
        [1, t, t ** 2, t ** 3] |> Nx.tensor()

      1 ->
        [0, 1, 2 * t, 3 * t ** 2] |> Nx.tensor()

      2 ->
        [0, 0, 2, 6 * t] |> Nx.tensor()

      3 ->
        [0, 0, 0, 6] |> Nx.tensor()
    end
  end

  defmacro __using__(opts) do
    quote do
      import Nx, only: :sigils
      @behaviour Curves.Formula
      @derivative Keyword.get(unquote(opts), :derivative, 0)

      @impl true
      def power_series(t), do: Curves.Formula.build_power_series(t, @derivative)
      defoverridable power_series: 1

      @impl true
      def required_opts(), do: []
      defoverridable required_opts: 0

      # @impl true
      # def points_function(points) do
      #  {dimensions, size} = Nx.shape(points)
      #  Nx.slice(points, [0, 0], [dimensions, size])
      # end
      # defoverridable points_function: 1
    end
  end
end
