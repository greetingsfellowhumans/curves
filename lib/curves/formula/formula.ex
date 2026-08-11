defmodule Curves.Formula do
  @moduledoc false

  @callback power_series(t :: float()) :: Nx.Tensor.t()
  @callback blending_function() :: struct()
  @callback points_function(points :: Nx.Tensor.t()) :: Nx.Tensor.t()
  @callback required_opts() :: list()
  @callback point_count() :: integer()


  @doc """
  get the power_series based on the target derivative
  """
  @spec get_derivative(t :: float(), derivative :: integer(), dir :: :asc | :desc) :: Nx.Tensor.t()
  def get_derivative(t, derivative, dir) do
    d = case derivative do
      0 -> [1, t, t ** 2, t ** 3]       # position
      1 -> [0, 1, 2 * t, 3 * (t ** 2)]  # velocity. where the velocity at the end of the first curve must equal that of the start of the next curve
      2 -> [0, 0, 2, 6 * t]             # acceleration
      3 -> [0, 0, 2, 6]                 # jolt
    end
    case dir do
      :asc -> Nx.tensor(d)
      :desc -> Nx.tensor(Enum.reverse(d))
    end
  end



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
      b = run(mod, points_after, t , opts)
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
