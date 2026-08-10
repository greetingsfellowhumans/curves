defmodule Curves.Bezier.CurveTest do
  use ExUnit.Case
  alias Curves.Bezier.Curve, as: Mod
  # import Mod
  doctest Mod

  test "Curve Struct" do
    c =
      Curves.define_curve([
        {0.1, 0.1},
        {0.2, 0.4},
        {0.5, 0.9},
        {0.9, 0.95}
      ])
    assert is_struct(c, Mod)

    {x, y} = Curves.solve!(c, 0.3)
    assert is_float(x)
    assert is_float(y)
    # assert p == {0.3695499897003174, 0.727199912071228}

    # Mod.print(c)
  end
end
