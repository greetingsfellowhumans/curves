defmodule Curves.Utils.DerivativesTest do
  import Curves.Utils.Derivatives
  use ExUnit.Case

  describe "Utils.Derivatives" do
    test "get_derivative/3" do
      assert get_derivative(0.5, 0, :asc) == Nx.tensor([1, 0.5, 0.25, 0.125])
      assert get_derivative(0.5, 0, :desc) == Nx.tensor([0.125, 0.25, 0.5, 1])
    end
  end
end
