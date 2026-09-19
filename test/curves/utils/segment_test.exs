defmodule Curves.Utils.SegmentTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Utils.Segment, as: Mod
  alias Curves.Utils.Point
  import Mod
  doctest Mod

  @curve0 [
    # P0
    [{5.0, 10.0},
      {10.0, 10.0}
    ],

    # P1
    [
     {10.0, 5.0},
     {5.0, 5.0},
    ],
  ]

  @curve1 [
    # P0
    [{5.0, 10.0},
      {10.0, 10.0}
    ],

    # P1
    [{10.0, 5.0},
     {5.0, 5.0},
     {15.0, 5.0}],

    # P2
    [{15.0, 10.0},
     {15.0, 6.0},
     {15.0, 14.0 }],

    # P3
    [{20.0, 15.0},
     {16.0, 15.0},
     {23.0, 15.0}],

    # P4
    [{25.0, 10.0},
     {20.0, 10.0}]
  ]
  @curve1_knot0 Point.new_point({5.0, 10.0})
  @curve1_knot1 Point.new_point({10.0, 5.0})
  @curve1_knot2 Point.new_point({15.0, 10.0})
  @curve1_knot3 Point.new_point({20.0, 15.0})
  @curve1_knot4 Point.new_point({25.0, 10.0})

  describe "Segment" do
    test "Given a list of lists, should normalize them into segments" do
      segments = new_segments(@curve0)
      assert Nx.shape(segments) == {1, 2, 4}

      segments = new_segments(@curve1)
      assert Nx.shape(segments) == {4, 2, 4}
    end

    property "should split_u, returning the right segment and t values" do
      segments = new_segments(@curve1)
      check all u <- StreamData.float(min: 0.0, max: 4.0) do
        {seg0, t} = split_u(segments, u)
        assert get_knot0(seg0) in [@curve1_knot0, @curve1_knot1, @curve1_knot2, @curve1_knot3]
        assert get_knot1(seg0) in [@curve1_knot1, @curve1_knot2, @curve1_knot3, @curve1_knot4]
        assert t >= 0.0
        assert t <= 1.0
      end
    end


    test "should split_u, returning the right segment and t" do
      segments = new_segments(@curve1)
      u = 0.31
      {seg, t} = split_u(segments, u)
      assert get_knot0(seg) == @curve1_knot0
      assert get_knot1(seg) == @curve1_knot1
      assert t == 0.31

      u = 4.0
      {seg, t} = split_u(segments, u)
      assert get_knot0(seg) == @curve1_knot3
      assert get_knot1(seg) == @curve1_knot4
      assert t == 1.0

      u = 1.5
      {seg, t} = split_u(segments, u)
      assert get_knot0(seg) == @curve1_knot1
      assert get_knot1(seg) == @curve1_knot2
      assert t == 0.5
    end

  end
end
