defmodule Curves.Transform.TransformTest do
  use ExUnit.Case
  alias Curves.Transform

  @spline_points [{5, 10}, {10, 5}, {15, 10}, {20, 10}, {25, 5}, {30, 15}]

  # Each entry builds a transformed curve from a freshly defined one.
  @transforms [
    origin: nil,
    set_position: {:set_position, [{3, 4}]},
    set_scale: {:set_scale, [2.0]},
    negative_scale: {:set_scale, [-1.5]},
    set_rotation: {:set_rotation, [90]},
    inc_rotation: {:inc_rotation, [33.0]}
  ]

  # Applies one entry from @transforms. `:origin` is a define option, not a transform.
  @spec build((keyword() -> struct()), atom(), {atom(), list()} | nil) :: struct()
  defp build(define, :origin, nil), do: define.(origin: {1, 2})
  defp build(define, _name, {func, args}), do: apply(Transform, func, [define.([]) | args])

  describe "apply_all_transformations/1" do
    for {name, spec} <- @transforms do
      @name name
      @transform spec

      test "bezier points stay {x, y} float tuples after #{name}" do
        curve = build(&Curves.define_bezier([{0, 0}, {1, 2}, {3, 1}], &1), @name, @transform)
        %{points: points} = Transform.apply_all_transformations(curve)
        assert length(points) == 3
        assert Enum.all?(points, fn {x, y} -> is_float(x) and is_float(y) end)
      end

      test "spline segments stay 4-point lists of float tuples after #{name}" do
        curve = build(&Curves.define_catmull_rom(@spline_points, &1), @name, @transform)
        %{segments: segments} = Transform.apply_all_transformations(curve)
        assert Enum.all?(segments, &(length(&1) == 4))

        assert segments
               |> List.flatten()
               |> Enum.all?(fn {x, y} -> is_float(x) and is_float(y) end)
      end

      test "transform_points/2 leaves the spline's points alone after #{name}" do
        curve = build(&Curves.define_catmull_rom(@spline_points, &1), @name, @transform)
        transformed = Transform.apply_all_transformations(curve)
        _copy = Transform.transform_points(transformed, transformed.points)
        assert transformed.points == curve.points
      end
    end
  end

  describe "rotation of 0" do
    test "rotating back to 0 or 0.0 matches never rotating" do
      bezier = &Curves.define_bezier([{0.1, 0.3}, {0.7, 1.9}, {2.3, 0.05}], &1)
      spline = &Curves.define_catmull_rom(@spline_points, &1)

      for define <- [bezier, spline] do
        curve = define.(origin: {10, 1000})

        for zero <- [0, 0.0] do
          rotated_back = curve |> Transform.set_rotation(37) |> Transform.set_rotation(zero)
          assert Curves.take!(rotated_back, 10) == Curves.take!(curve, 10)
        end
      end
    end
  end
end
