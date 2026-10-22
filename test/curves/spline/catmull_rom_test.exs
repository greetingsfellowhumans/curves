defmodule Curves.Spline.CatmullRomTest do
  use ExUnit.Case
  alias Curves.Spline.Type.CatmullRom, as: Mod
  import Mod
  import Curves.Support.SampleCurves

  setup [:with_curves]

  def initial_args(ctx, k \\ :catmull_rom) do
    curve_spec = ctx.curve_specs[k]
    bezier = Curves.define_spline(curve_spec, :bezier_spline)
    segments_list = Enum.with_index(bezier.segments)
    {segments_list, bezier}
  end

  describe "Catmull Rom Splines map_segments" do
    test "get initial arguments", ctx do
      {segments_list, curve} = initial_args(ctx)
      assert is_struct(curve, Curves.Spline.Curve)
      assert is_list(segments_list)
      [{hd, 0} | _] = segments_list

      # Bare knots make straight bezier-spline segments, with control points at a third and two thirds.
      assert hd == [{0.0, 0.0}, {1 / 3, 0.0}, {2 / 3, 0.0}, {1.0, 0.0}]
    end

    test "each segment gets the points before and after it, mirrored at the ends", ctx do
      {segments_list, curve} = initial_args(ctx)
      [first, second | _] = mapped = map_segments(segments_list, curve)

      assert first == [{-1.0, 0.0}, {0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}]
      assert second == [{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}]
      assert mapped |> List.last() |> Enum.drop(2) == [{1.0, 2.0}, {2.0, 2.0}]

      {segments_list, curve} = initial_args(ctx, :catmull_rom2)
      [first, second | _] = mapped = map_segments(segments_list, curve)

      assert {hd(first), List.last(first)} == {{8.0, 22.0}, {14.0, 16.0}}
      assert {hd(second), List.last(second)} == {{10.0, 20.0}, {15.0, 14.0}}
      assert mapped |> List.last() |> Enum.drop(2) == [{18.0, 10.0}, {20.0, 8.0}]
    end

    test "a single segment is mirrored at both ends" do
      segment = [{0.0, 0.0}, {1.0, 0.0}, {2.0, 0.0}, {3.0, 0.0}]

      assert map_segments([{segment, 0}], nil) == [
               [{-3.0, 0.0}, {0.0, 0.0}, {3.0, 0.0}, {6.0, 0.0}]
             ]
    end

    # test "get slope", ctx do
    #  {segments_list, curve} = initial_args(ctx, :catmull_rom2)
    #  {rise, run} = get_slope({12, 18}, {15, 14})
    #  assert rise == -4
    #  assert run == 3
    # end

    # test "get control points", ctx do
    #  {segments_list, curve} = initial_args(ctx, :catmull_rom2)
    #  {cx, cy} = get_control_point({14, 16}, {12, 18}, {15, 14})
    #  assert cx == 14 + 3
    #  assert cy == 16 - 4
    # end
  end
end
