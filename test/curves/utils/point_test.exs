defmodule Curves.Utils.PointTest do
  use ExUnit.Case
  alias Curves.Utils.Point, as: Mod
  import Mod
  doctest Mod

  describe "Point" do
    test "new point" do
      p = new_point({0, 10}, float_dtype: 32)
      assert Nx.type(p) == {:f, 32}

      p = new_point({0, 10}, float_dtype: 16)
      assert Nx.type(p) == {:f, 16}

      assert Mod.get_x(p) == 0.0
      assert Mod.get_y(p) == 10.0

      assert Nx.shape(p) == {2, 1}
    end
  end
end
