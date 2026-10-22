defmodule Curves.Svg.PathDataTest do
  use ExUnit.Case, async: true
  alias Curves.Svg.PathData

  # Tricky but valid path data, and the bezier spline points it should give.
  @cases [
    {"M 0 0 L 10 0", [[{0.0, 0.0}], [{10.0, 0.0}]]},
    # No separators where the numbers can't run together
    {"M0,0L10-5", [[{0.0, 0.0}], [{10.0, -5.0}]]},
    {"M.5.5L1.5.5", [[{0.5, 0.5}], [{1.5, 0.5}]]},
    {"M-.5+.5l1.e1,2E-1", [[{-0.5, 0.5}], [{9.5, 0.7}]]},
    # Extra pairs after M are lines; after m, relative lines
    {"M0 0 1 1 2 0", [[{0.0, 0.0}], [{1.0, 1.0}], [{2.0, 0.0}]]},
    {"m1 1 2 2", [[{1.0, 1.0}], [{3.0, 3.0}]]},
    # H and V, absolute and relative
    {"M1 1 H5 V4 h-2 v-1",
     [[{1.0, 1.0}], [{5.0, 1.0}], [{5.0, 4.0}], [{3.0, 4.0}], [{3.0, 3.0}]]},
    # S mirrors the last control point of a C, but not after anything else
    {"M0 0 C1 1 2 2 3 3 S5 5 6 6",
     [[{0.0, 0.0}, {1.0, 1.0}, {2.0, 2.0}], [{3.0, 3.0}, {4.0, 4.0}, {5.0, 5.0}], [{6.0, 6.0}]]},
    {"M0 0 L3 3 S5 5 6 6", [[{0.0, 0.0}], [{3.0, 3.0}, {3.0, 3.0}, {5.0, 5.0}], [{6.0, 6.0}]]},
    # T mirrors the control point of a Q
    {"M0 0 Q1 1 2 0 T4 0", [[{0.0, 0.0}, {1.0, 1.0}], [{2.0, 0.0}, {3.0, -1.0}], [{4.0, 0.0}]]},
    {"M0 0 q1 1 2 0 t2 0", [[{0.0, 0.0}, {1.0, 1.0}], [{2.0, 0.0}, {3.0, -1.0}], [{4.0, 0.0}]]},
    # Arc flags squashed together
    {"M0 0 a1 1 0 0010 10", [[{0.0, 0.0}, {:arc, 1.0, 1.0, 0.0, false, false}], [{10.0, 10.0}]]},
    {"M0 0A5,5,30,1,1,10,0", [[{0.0, 0.0}, {:arc, 5.0, 5.0, 30.0, true, true}], [{10.0, 0.0}]]},
    # A comma between repeated sets of arguments
    {"M0,0,10,10", [[{0.0, 0.0}], [{10.0, 10.0}]]},
    {"M0 0 L1 2,3 4", [[{0.0, 0.0}], [{1.0, 2.0}], [{3.0, 4.0}]]},
    {"M0 0 A1 1 0 0 1 5 5 , 1 1 0 0 1 6 6",
     [
       [{0.0, 0.0}, {:arc, 1.0, 1.0, 0.0, false, true}],
       [{5.0, 5.0}, {:arc, 1.0, 1.0, 0.0, false, true}],
       [{6.0, 6.0}]
     ]}
  ]

  for {data, points} <- @cases do
    @data data
    @points points
    test "reads #{inspect(data)}" do
      assert PathData.parse(@data) == {:ok, [{@points, false}]}
    end
  end

  test "Z closes back to the start, and the next command starts there" do
    assert PathData.parse("M0 0 L1 0 L1 1 Z l0 1") ==
             {:ok,
              [
                {[[{0.0, 0.0}], [{1.0, 0.0}], [{1.0, 1.0}], [{0.0, 0.0}]], true},
                {[[{0.0, 0.0}], [{0.0, 1.0}]], false}
              ]}
  end

  test "Z when already at the start adds no line" do
    assert PathData.parse("M0 0 L1 0 L0 0 Z") ==
             {:ok, [{[[{0.0, 0.0}], [{1.0, 0.0}], [{0.0, 0.0}]], true}]}
  end

  test "each M starts a new subpath; relative m is from the end of the last one" do
    assert {:ok, [{_, true}, {[[{12.0, 2.0}], [{13.0, 2.0}]], false}]} =
             PathData.parse("M2 2 h5 v5 z m10 0 h1")
  end

  test "subpaths that draw nothing are dropped" do
    assert PathData.parse("") == {:ok, []}
    assert PathData.parse("M 1 1") == {:ok, []}
    assert PathData.parse("M 1 1 M 2 2 L 3 3") == {:ok, [{[[{2.0, 2.0}], [{3.0, 3.0}]], false}]}
    assert PathData.parse("M 1 1 Z") == {:ok, []}
  end

  test "an error keeps what came before it, like a browser" do
    assert PathData.parse("M0 0 L1 1 L2") ==
             {:error, [{[[{0.0, 0.0}], [{1.0, 1.0}]], false}],
              "expected a number, got: the end in the L command"}
  end

  test "errors say what was wrong" do
    for {data, message} <- [
          {"L1 1", "path data must start with M or m, got: \"L1 1\""},
          {"M0 0 X1", "expected a path command, got: \"X1\""},
          {"M0 0 A1 1 0 2 0 5 5",
           "expected an arc flag (0 or 1), got: \"2 0 5 5\" in the A command"},
          {"M0 0 L1 1e400", "number too big: \"1e400\" in the L command"},
          {"M0 0 Z 5", "expected a path command, got: \"5\""},
          {"M0 0 L1 1,", "expected a number, got: the end in the L command"},
          {"M0 0 L1 1,L2 2", "expected a number, got: \"L2 2\" in the L command"}
        ] do
      assert {:error, _subpaths, ^message} = PathData.parse(data)
    end
  end

  test "numbers/1 reads a list of numbers, stopping at an error" do
    assert PathData.numbers(" 0,0 10,5\n20 0 .5-.5 1e2 ") ==
             {[0.0, 0.0, 10.0, 5.0, 20.0, 0.0, 0.5, -0.5, 100.0], nil}

    assert PathData.numbers("1 2 x") == {[1.0, 2.0], "expected a number, got: \"x\""}
  end
end
