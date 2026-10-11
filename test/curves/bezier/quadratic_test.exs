defmodule Curves.Bezier.QuadraticTest do
  use ExUnit.Case
  alias Curves.Bezier.Quadratic, as: Mod
  alias Curves.Utils.Points
  # import Point
  import Mod
  # doctest Mod

  test "Quadratic interpolation" do
    points =
      Points.new_points([
        {10, 10},
        {20, 40},
        {30, 60}
      ])

    t = 0.5
    p3 = get_quadratic_point(points, t)

    assert Nx.to_number(p3[1][0]) == 37.5

    # p0 = Points.point_at(points, 0)
    # p1 = Points.point_at(points, 1)
    # p2 = Points.point_at(points, 2)
    # assert get_quadratic_bezier_curve(p0, p1, p2, t) == expected_p3

    # t = 0.25
    # expected_p2 = Nx.tensor([4.0625, 2.875])
    # assert get_quadratic_bezier_curve(p0, pc, p1, t) == expected_p2
  end

  # Exact outputs recorded from the original `defn` version, so any rewrite must match bit for bit.
  # Each row is {t, output type, point}. Integer t keeps the points' type; float t is f32 unless the points are f64.
  @recorded %{
    16 => [
      {0, {:f, 16}, {10.0, 10.0}},
      {1, {:f, 16}, {35.0, 61.0}},
      {0.0, {:f, 32}, {10.0, 10.0}},
      {0.25, {:f, 32}, {15.3125, 24.4375}},
      {0.3, {:f, 32}, {16.450000762939453, 27.190000534057617}},
      {0.5, {:f, 32}, {21.25, 37.75}},
      {0.7, {:f, 32}, {26.450000762939453, 47.59000015258789}},
      {1.0, {:f, 32}, {35.0, 61.0}}
    ],
    32 => [
      {0, {:f, 32}, {10.0, 10.0}},
      {1, {:f, 32}, {35.0, 61.0}},
      {0.0, {:f, 32}, {10.0, 10.0}},
      {0.25, {:f, 32}, {15.3125, 24.4375}},
      {0.3, {:f, 32}, {16.450000762939453, 27.190000534057617}},
      {0.5, {:f, 32}, {21.25, 37.75}},
      {0.7, {:f, 32}, {26.450000762939453, 47.59000015258789}},
      {1.0, {:f, 32}, {35.0, 61.0}}
    ],
    64 => [
      {0, {:f, 64}, {10.0, 10.0}},
      {1, {:f, 64}, {35.0, 61.0}},
      {0.0, {:f, 64}, {10.0, 10.0}},
      {0.25, {:f, 64}, {15.3125, 24.4375}},
      {0.3, {:f, 64}, {16.450000256299973, 27.19000068306923}},
      {0.5, {:f, 64}, {21.25, 37.75}},
      {0.7, {:f, 64}, {26.449999660253525, 47.589999467134476}},
      {1.0, {:f, 64}, {35.0, 61.0}}
    ]
  }

  for {dtype, rows} <- @recorded do
    test "get_quadratic_point matches recorded f#{dtype} outputs exactly" do
      points =
        Points.new_points([{10.0, 10.0}, {20.0, 40.0}, {35.0, 61.0}], float_dtype: unquote(dtype))

      for {t, type, expected} <- unquote(Macro.escape(rows)) do
        result = get_quadratic_point(points, t)
        assert Nx.type(result) == type, "type for t = #{inspect(t)}"
        assert Nx.shape(result) == {2, 1}
        assert result.names == [:dimension, :point]
        assert Curves.Utils.Point.to_tuple(result) == expected, "value for t = #{inspect(t)}"
      end
    end
  end
end
