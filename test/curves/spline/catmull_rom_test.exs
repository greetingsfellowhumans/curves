defmodule Curves.Spline.CatmullRomTest do
  use ExUnit.Case
  alias Curves.Spline.Type.CatmullRom, as: Mod
  import Mod
  import Curves.Support.SampleCurves

  setup [:with_curves]

  def initial_args(ctx, k \\ :catmull_rom) do
    curve_spec = ctx.curve_specs[k]
    bezier = Curves.define_spline(curve_spec, :bezier_spline)
    segments_list = Nx.to_list(bezier.segments) |> Enum.with_index()
    {segments_list, bezier}
  end

  describe "Catmull Rom Splines map_segments" do

    test "get initial arguments", ctx do
      {segments_list, curve} = initial_args(ctx)
      assert is_struct(curve, Curves.Spline.Curve)
      assert is_list(segments_list)
      [{hd, 0} | _] = segments_list
      assert hd == [[0.0, 0.0, 1.0, 1.0], [0.0, 0.0, 0.0, 0.0]]
    end


    test "get_prev and get_next", ctx do
      {segments_list, _curve} = initial_args(ctx)
      [{first, 0}, {second, 1} | _] = segments_list
      assert first == [[0.0, 0.0, 1.0, 1.0], [0.0, 0.0, 0.0, 0.0]]
      assert second == [[1.0, 1.0, 1.0, 1.0], [0.0, 0.0, 1.0, 1.0]]

      assert get_prev_coord(segments_list, 1, second) == {0.0, 0.0}
      assert get_prev_coord(segments_list, 0, first) == {-1.0, 0.0}

      assert get_next_coord(segments_list, 0, first) == {1.0, 1.0}
      assert get_next_coord(segments_list, 1, second) == {0.0, 1.0}

      {last, _} = Enum.at(segments_list, Enum.count(segments_list) - 1)
      [[_, _, _, 1.0], [_, _, _, 2.0]] = last

      assert get_next_coord(segments_list, Enum.count(segments_list) - 1, last) == {2.0, 2.0}

      {segments_list, _curve} = initial_args(ctx, :catmull_rom2)
      [{first, 0}, {second, 1} | _] = segments_list

      assert get_prev_coord(segments_list, 0, first) == {8.0, 22.0}
      assert get_prev_coord(segments_list, 1, second) == {10.0, 20.0}
      assert get_next_coord(segments_list, 0, first) == {14.0, 16.0}
      assert get_next_coord(segments_list, 1, second) == {15.0, 14.0}

      {last, _} = Enum.at(segments_list, Enum.count(segments_list) - 1)
      [[_, _, _, 18.0], [_, _, _, 10.0]] = last
      assert get_next_coord(segments_list, Enum.count(segments_list) - 1, last) == {20.0, 8.0}
    end
    #test "get slope", ctx do
    #  {segments_list, curve} = initial_args(ctx, :catmull_rom2)
    #  {rise, run} = get_slope({12, 18}, {15, 14})
    #  assert rise == -4
    #  assert run == 3
    #end

    #test "get control points", ctx do
    #  {segments_list, curve} = initial_args(ctx, :catmull_rom2)
    #  {cx, cy} = get_control_point({14, 16}, {12, 18}, {15, 14})
    #  assert cx == 14 + 3
    #  assert cy == 16 - 4
    #end
  end

end
