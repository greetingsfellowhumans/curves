defmodule Curves.Formula do
  @moduledoc false

  @callback power_series(t :: float()) :: Nx.Tensor.t()
  @callback blending_function() :: struct()
  @callback required_opts() :: list()
  @callback point_count() :: integer()


  def run(mod, points, t, opts \\ []) do
    {_, size} = Nx.shape(points)

    if size <= 4 do
      mod.power_series(t)
      |> Nx.dot(mod.blending_function())
      |> Nx.multiply(points)
      |> Nx.window_sum({1, mod.point_count()})
    else
      points_before = Nx.slice(points, [0, 0], [2, 4])
      points_after = Nx.slice(points, [0, 3], [2, 4])
      a = run(mod, points_before, t, opts)
      b = run(mod, points_after, t, opts)
      {a, b}
    end
  end


  def build_power_series(t, derivative \\ 0) do
    case derivative do
      0.5 -> 
        [1, t, t ** 2, t ** 3]
        |> Nx.tensor()
        |> Nx.divide(2)
      0 -> [1, t, t ** 2, t ** 3] |> Nx.tensor()
      1 -> [0, 1, 2 * t, 3 * (t ** 2)] |> Nx.tensor()
      2 -> [0, 0, 2, 6 * t] |> Nx.tensor()
      3 -> [0, 0, 0, 6] |> Nx.tensor()
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

      #@impl true
      #def points_function(points) do
      #  {dimensions, size} = Nx.shape(points)
      #  Nx.slice(points, [0, 0], [dimensions, size])
      #end
      #defoverridable points_function: 1


    end
  end
end
