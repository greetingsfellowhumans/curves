defmodule Curves.Utils.NumbersTest do
  use ExUnit.Case
  alias Curves.Utils.Numbers, as: Mod
  import Mod

  describe "Number utilities" do
    test "split_float/1" do
      assert split_float(5.25) == {5, 0.25}
      assert split_float(5.0) == {5, 0.0}
      assert split_float(0.5) == {0, 0.5}
      assert split_float(1234.56789) == {1234, 0.56789}
    end
  end
end
