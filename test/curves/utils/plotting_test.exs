defmodule Curves.Utils.PlottingTest do
  use ExUnit.Case
  alias Curves.Utils.Plotting, as: Mod
  import Mod

  describe "Plotting utilities" do
    test "curve_to_scatterplot/2" do
      curve = Curves.define_bezier(:ease_in_out_back)
      li = curve_to_scatterplot(curve)
      assert Enum.count(li) == 1002
      li = curve_to_scatterplot(curve, count: 100)
      assert Enum.count(li) == 102
      li = curve_to_scatterplot(curve, count: 100, label: "foo")
      [item | _] = li
      assert is_float(item.x)
      assert is_float(item.y)
      assert item.label == "foo"

      cp = Enum.filter(li, &(&1.label =~ "control point"))
      assert Enum.count(cp) == 2
    end
  end
end
