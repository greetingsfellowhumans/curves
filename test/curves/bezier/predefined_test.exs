defmodule Curves.Bezier.PredefinedTest do
  use ExUnit.Case
  #alias Curves.Bezier.Predefined, as: Mod


  test "Predefined points" do
    cubic = Curves.define_bezier(:ease_in_cubic)
    assert is_struct(cubic, Curves.Bezier.Curve)
  end

  test "divide by zero bug" do
    linear = Curves.define_bezier(:linear_horizontal)
    assert is_struct(linear, Curves.Bezier.Curve)
    assert {:ok, _point} = Curves.solve(linear, 0.5, force_percent: true)
  end
end
