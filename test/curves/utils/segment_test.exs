defmodule Curves.Utils.SegmentTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Utils.Segment

  # SVG-style: a knot, then the control points of the curve to the next knot.
  @curve1 [
    [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],
    [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}],
    [{15.0, 10.0}, {15.0, 14.0}, {16.0, 15.0}],
    [{20.0, 15.0}, {23.0, 15.0}, {20.0, 10.0}],
    [{25.0, 10.0}]
  ]

  describe "new_segments/1" do
    test "makes one 4-point segment per pair of neighbouring points" do
      assert length(Segment.new_segments(@curve1)) == 4
    end

    test "[knot, c0, c1] is a cubic curve to the next knot (SVG C)" do
      [_, second | _] = Segment.new_segments(@curve1)
      assert second == [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}, {15.0, 10.0}]
    end

    test "[knot] is a straight line, with control points at a third and two thirds (SVG L)" do
      assert Segment.new_segments([[{0, 0}], [{3, 6}]]) ==
               [[{0.0, 0.0}, {1.0, 2.0}, {2.0, 4.0}, {3.0, 6.0}]]
    end

    test "[knot, c] is a quadratic curve, written exactly as a cubic (SVG Q)" do
      assert Segment.new_segments([[{0, 0}, {3, 3}], [{6, 0}]]) ==
               [[{0.0, 0.0}, {2.0, 2.0}, {4.0, 2.0}, {6.0, 0.0}]]
    end

    test "a single knot is one segment that stays on it" do
      assert Segment.new_segments([[{1, 2}]]) == [
               [{1.0, 2.0}, {1.0, 2.0}, {1.0, 2.0}, {1.0, 2.0}]
             ]
    end

    test "the last point must be just a knot" do
      for points <- [[[{0, 0}], [{1, 1}, {2, 2}]], [[{0, 0}, {1, 1}, {2, 2}]]] do
        assert_raise ArgumentError,
                     ~r/the last point of a bezier spline only ends the curve/,
                     fn ->
                       Segment.new_segments(points)
                     end
      end
    end

    test "turns integer coordinates into floats" do
      assert [[{0.0, 0.0}, {1.0, 1.0}, {1.0, 1.0}, {2.0, 0.0}]] =
               Segment.new_segments([[{0, 0}, {1, 1}, {1, 1}], [{2, 0}]])
    end
  end

  describe "control_lines/1 and handle_lines/3" do
    test "each control point is joined to the knot it pulls on" do
      assert Segment.control_lines([
               [{0, 0}, {1, 1}, {2, 1}],
               [{3, 0}, {4, 1}],
               [{6, 0}],
               [{7, 0}]
             ]) == [
               [{0.0, 0.0}, {1.0, 1.0}],
               [{2.0, 1.0}, {3.0, 0.0}],
               [{3.0, 0.0}, {4.0, 1.0}, {6.0, 0.0}]
             ]
    end

    test "a straight line has none" do
      assert Segment.handle_lines({0, 0}, [], {1, 1}) == []
    end
  end

  describe "split_u/1" do
    test "finds the segment index and how far along it u is" do
      assert Segment.split_u(0.0) == {0, 0.0}
      assert Segment.split_u(0.31) == {0, 0.31}
      assert Segment.split_u(1.5) == {1, 0.5}
    end

    test "a whole number u is the end of the previous segment" do
      assert Segment.split_u(1.0) == {0, 1.0}
      assert Segment.split_u(4.0) == {3, 1.0}
    end

    test "a small negative u stays in the first segment with a negative t" do
      assert Segment.split_u(-0.0005) == {0, -0.0005}
    end

    property "t is always within 0..1 for u within 0..max_u" do
      check all(u <- StreamData.float(min: 0.0, max: 4.0)) do
        {index, t} = Segment.split_u(u)
        assert index in 0..3
        assert t >= 0.0 and t <= 1.0
      end
    end
  end
end
