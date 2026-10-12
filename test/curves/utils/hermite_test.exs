defmodule Curves.Utils.HermiteTest do
  use ExUnit.Case, async: true
  alias Curves.Utils.Hermite

  test "bezier_segment/4 puts the control points a third of each tangent from the knots" do
    assert Hermite.bezier_segment({0.0, 0.0}, {3.0, 0.0}, {6.0, 6.0}, {0.0, 6.0}) ==
             [{0.0, 0.0}, {1.0, 0.0}, {6.0, 4.0}, {6.0, 6.0}]
  end

  test "bezier_segments/1 leaves each knot with its outgoing tangent and arrives with the incoming one" do
    knots = [
      {{0.0, 0.0}, {9.0, 9.0}, {3.0, 0.0}},
      {{6.0, 0.0}, {3.0, 3.0}, {0.0, 3.0}},
      {{6.0, 6.0}, {0.0, 3.0}, {9.0, 9.0}}
    ]

    assert Hermite.bezier_segments(knots) == [
             [{0.0, 0.0}, {1.0, 0.0}, {5.0, -1.0}, {6.0, 0.0}],
             [{6.0, 0.0}, {6.0, 1.0}, {6.0, 5.0}, {6.0, 6.0}]
           ]

    assert Hermite.bezier_segments([{{1.0, 2.0}, {9.0, 9.0}, {9.0, 9.0}}]) == [
             [{1.0, 2.0}, {1.0, 2.0}, {1.0, 2.0}, {1.0, 2.0}]
           ]
  end

  test "same_both_sides/2 uses each tangent on both sides of its knot" do
    assert Hermite.same_both_sides([{0.0, 0.0}, {1.0, 1.0}], [{2.0, 0.0}, {0.0, 2.0}]) ==
             [{{0.0, 0.0}, {2.0, 0.0}, {2.0, 0.0}}, {{1.0, 1.0}, {0.0, 2.0}, {0.0, 2.0}}]
  end

  test "neighbours/1 mirrors a made-up knot past each end" do
    assert Hermite.neighbours([{0.0, 0.0}, {1.0, 2.0}, {3.0, 2.0}]) == [
             {{-1.0, -2.0}, {0.0, 0.0}, {1.0, 2.0}},
             {{0.0, 0.0}, {1.0, 2.0}, {3.0, 2.0}},
             {{1.0, 2.0}, {3.0, 2.0}, {5.0, 2.0}}
           ]
  end
end
