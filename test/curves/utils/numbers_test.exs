defmodule Curves.Utils.NumbersTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Curves.Utils.Numbers, as: Mod
  import Mod

  describe "Number utilities" do
    test "split_float/1" do
      assert split_float(5.25) == {5, 0.25}
      assert split_float(5.0) == {5, 0.0}
      assert split_float(0.5) == {0, 0.5}
      assert split_float(1234.56789) == {1234, 0.56789}
    end

    # Elixir prints floats below 0.0001 in scientific notation (e.g. "1.0e-5").
    test "split_float/1 keeps tiny fractions" do
      assert split_float(1.0e-5) == {0, 1.0e-5}
      assert split_float(9.99e-5) == {0, 9.99e-5}
      assert split_float(1.0e16) == {10_000_000_000_000_000, 0.0}
    end

    test "split_float/1 keeps the sign of negative floats" do
      assert split_float(-0.0005) == {0, -0.0005}
      assert split_float(-2.25) == {-2, -0.25}
    end

    test "split_float/1 turns -0.0 into +0.0" do
      assert {0, fraction} = split_float(-0.0)
      assert fraction === +0.0
    end

    property "split_float/1 returns any float between 0 and 1 unchanged as the fraction" do
      # Bounds just inside 0 and 1, so no values need filtering out (that made this flaky).
      check all(f <- StreamData.float(min: 1.0e-300, max: 0.9999999999999999)) do
        assert split_float(f) === {0, f}
      end
    end
  end
end
