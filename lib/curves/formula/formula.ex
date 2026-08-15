defmodule Curves.Formula do
  @moduledoc false

  @callback power_series(t :: float()) :: Nx.Tensor.t()
  @callback blending_function() :: struct()
  @callback points_function(points :: Nx.Tensor.t()) :: Nx.Tensor.t()
  @callback required_opts() :: list()
  @callback point_count() :: integer()


  def run(mod, points, t, opts \\ []) do
    {_, size} = Nx.shape(points)

    if size <= 4 do
      mod.power_series(t)
      |> Nx.dot(mod.blending_function())
      |> Nx.multiply(mod.points_function(points))
      |> Nx.window_sum({1, mod.point_count()})
    else
      points_before = Nx.slice(points, [0, 0], [2, 4])
      points_after = Nx.slice(points, [0, 3], [2, 4])
      a = run(mod, points_before, t, opts)
      b = run(mod, points_after, t, opts)
      {a, b}
    end
  end

  defmacro __using__(_) do
    quote do
      import Nx, only: :sigils
      @behaviour Curves.Formula
    end
  end
end
