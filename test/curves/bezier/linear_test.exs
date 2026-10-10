defmodule Curves.Bezier.LinearTest do
  use ExUnit.Case
  require Curves.Utils.Point
  alias Curves.Bezier.Linear, as: Mod
  alias Curves.Utils.{Point, Points}
  import Mod
  doctest Mod

  test "Linear interpolation" do
    opts = []

    coords = [
      {0, 0},
      {10, 10}
    ]

    p = Points.new_points(coords, opts)
    p0 = Points.point_at(p, 0)
    p1 = Points.point_at(p, 1)
    t = 0.5
    p2 = get_linear_interpolation_point(p0, p1, t)
    assert Point.is_point(p2)
    assert Point.get_x(p2) == 5.0
    assert Point.get_y(p2) == 5.0
  end

  # Exact outputs recorded from the original `defn` version of get_linear_interpolation_point/2,
  # so any rewrite must match bit for bit. Each row is {t, output type, point}.
  @recorded %{
    16 => [
      {0, {:f, 16}, {10.0, 10.0}},
      {1, {:f, 16}, {35.0, 61.0}},
      {0.0, {:f, 32}, {10.0, 10.0}},
      {0.25, {:f, 32}, {16.25, 22.75}},
      {0.3, {:f, 32}, {17.5, 25.299999237060547}},
      {0.5, {:f, 32}, {22.5, 35.5}},
      {0.7, {:f, 32}, {27.5, 45.70000076293945}},
      {1.0, {:f, 32}, {35.0, 61.0}}
    ],
    32 => [
      {0, {:f, 32}, {10.0, 10.0}},
      {1, {:f, 32}, {35.0, 61.0}},
      {0.0, {:f, 32}, {10.0, 10.0}},
      {0.25, {:f, 32}, {16.25, 22.75}},
      {0.3, {:f, 32}, {17.5, 25.299999237060547}},
      {0.5, {:f, 32}, {22.5, 35.5}},
      {0.7, {:f, 32}, {27.5, 45.70000076293945}},
      {1.0, {:f, 32}, {35.0, 61.0}}
    ],
    64 => [
      {0, {:f, 64}, {10.0, 10.0}},
      {1, {:f, 64}, {35.0, 61.0}},
      {0.0, {:f, 64}, {10.0, 10.0}},
      {0.25, {:f, 64}, {16.25, 22.75}},
      {0.3, {:f, 64}, {17.500000298023224, 25.300000607967377}},
      {0.5, {:f, 64}, {22.5, 35.5}},
      {0.7, {:f, 64}, {27.499999701976776, 45.69999939203262}},
      {1.0, {:f, 64}, {35.0, 61.0}}
    ]
  }

  for {dtype, rows} <- @recorded do
    test "get_linear_interpolation_point/2 matches recorded f#{dtype} outputs exactly" do
      points = Points.new_points([{10.0, 10.0}, {35.0, 61.0}], float_dtype: unquote(dtype))

      for {t, type, expected} <- unquote(Macro.escape(rows)) do
        result = get_linear_interpolation_point(points, t)
        assert Nx.type(result) == type, "type for t = #{inspect(t)}"
        assert Nx.shape(result) == {2}
        assert result.names == [:dimension]
        assert Point.to_tuple(result) == expected, "value for t = #{inspect(t)}"
      end
    end
  end
end
