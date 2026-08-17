defmodule Curves.Bezier.PredefinedTest do
  use ExUnit.Case
  #alias Curves.Bezier.Predefined, as: Mod


  test "Predefined points" do
    cubic = Curves.define_bezier(:ease_in_cubic)
    assert is_struct(cubic, Curves.Bezier.Curve)
  end
end
