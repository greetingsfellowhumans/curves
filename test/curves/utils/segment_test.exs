defmodule Curves.Utils.SegmentTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Utils.Segment

  @curve0 [
    [{5.0, 10.0}, {10.0, 10.0}],
    [{10.0, 5.0}, {5.0, 5.0}]
  ]

  @curve1 [
    [{5.0, 10.0}, {10.0, 10.0}],
    [{10.0, 5.0}, {5.0, 5.0}, {15.0, 5.0}],
    [{15.0, 10.0}, {15.0, 6.0}, {15.0, 14.0}],
    [{20.0, 15.0}, {16.0, 15.0}, {23.0, 15.0}],
    [{25.0, 10.0}, {20.0, 10.0}]
  ]

  describe "new_segments/1" do
    test "makes one 4-point segment per pair of neighbouring points" do
      assert [segment] = Segment.new_segments(@curve0)
      assert segment == [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}, {10.0, 5.0}]
      assert length(Segment.new_segments(@curve1)) == 4
    end

    test "each segment is [knot, control after it, control before the next knot, next knot]" do
      [_, second | _] = Segment.new_segments(@curve1)
      assert second == [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}, {15.0, 10.0}]
    end

    test "turns integer coordinates into floats" do
      assert [[{0.0, 0.0}, {1.0, 1.0}, {1.0, 1.0}, {2.0, 0.0}]] =
               Segment.new_segments([[{0, 0}, {1, 1}], [{2, 0}, {1, 1}]])
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
