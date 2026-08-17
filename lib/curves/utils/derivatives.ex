defmodule Curves.Utils.Derivatives do
  @moduledoc false

  @doc """
  Get the power_series based on the target derivative.
  This can be plugged directly into the matrix form calculation

  ## Examples
      iex> get_derivative(0.5, 0, :asc)
      Nx.tensor([1, 0.5, 0.25, 0.125])
      iex> get_derivative(0.5, 0, :desc)
      Nx.tensor([0.125, 0.25, 0.5, 1])
  """
  @spec get_derivative(t :: float(), derivative :: integer(), dir :: :asc | :desc) ::
          Nx.Tensor.t()
  def get_derivative(t, derivative, dir) do
    d =
      case derivative do
        # position
        0 -> [1, t, t ** 2, t ** 3]
        # velocity. where the velocity at the end of the first curve must equal that of the start of the next curve
        1 -> [0, 1, 2 * t, 3 * t ** 2]
        # acceleration
        2 -> [0, 0, 2, 6 * t]
        # jolt
        3 -> [0, 0, 0, 6]
      end

    case dir do
      :asc -> Nx.tensor(d)
      :desc -> Nx.tensor(Enum.reverse(d))
    end
  end

end
