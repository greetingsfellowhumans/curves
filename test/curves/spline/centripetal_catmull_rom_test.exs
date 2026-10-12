defmodule Curves.Spline.CentripetalCatmullRomTest do
  use ExUnit.Case, async: true

  # Two knots close together between two far away: plain Catmull-Rom makes a loop here.
  @bunched [{0, 0}, {10, 10}, {10.5, 10}, {20, 0}]

  # Checks two points are equal to within float rounding.
  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  # Whether x ever goes back on itself along the middle segment.
  @spec doubles_back?(Curves.Spline.Curve.t()) :: boolean()
  defp doubles_back?(curve) do
    for(i <- 0..200, do: elem(Curves.solve!(curve, 1 + i / 200), 0))
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [a, b] -> b < a end)
  end

  test "passes through every knot" do
    curve = Curves.define_centripetal_catmull_rom(@bunched)
    assert Curves.max_u(curve) == 3.0

    for {{x, y}, i} <- Enum.with_index(@bunched),
        do: assert_near(Curves.solve!(curve, i * 1.0), {x * 1.0, y * 1.0})
  end

  test "plain Catmull-Rom loops between bunched-up knots; centripetal and chordal don't" do
    assert doubles_back?(Curves.define_catmull_rom(@bunched))
    refute doubles_back?(Curves.define_centripetal_catmull_rom(@bunched))
    refute doubles_back?(Curves.define_centripetal_catmull_rom(@bunched, alpha: 1))
  end

  test "alpha 0 is Catmull-Rom, even with knots in the same place" do
    for knots <- [@bunched, [{0, 0}, {1, 1}, {1, 1}, {2, 0}]] do
      catmull_rom = Curves.define_catmull_rom(knots)
      curve = Curves.define_centripetal_catmull_rom(knots, alpha: 0)

      for u <- [0.0, 0.4, 1.5, 2.9, 3.0],
          do: assert_near(Curves.solve!(curve, u), Curves.solve!(catmull_rom, u))
    end
  end

  test "two knots in the same place make a segment that stays there" do
    curve = Curves.define_centripetal_catmull_rom([{0, 0}, {1, 1}, {1, 1}, {2, 0}])
    for u <- [1.0, 1.25, 1.5, 2.0], do: assert_near(Curves.solve!(curve, u), {1.0, 1.0})

    # Every knot in the same place
    assert Curves.take!(Curves.define_centripetal_catmull_rom([{2, 2}, {2, 2}, {2, 2}]), 2) ==
             [{2.0, 2.0}, {2.0, 2.0}]
  end

  test "stores the knots as its points" do
    curve = Curves.define_centripetal_catmull_rom(@bunched)
    assert curve.points == Enum.map(@bunched, fn {x, y} -> {x * 1.0, y * 1.0} end)
    assert curve.type == :centripetal_catmull_rom
  end

  test "an alpha outside 0..1, or not a number, raises an ArgumentError" do
    for alpha <- [-0.1, 1.5] do
      assert_raise ArgumentError,
                   "the :alpha option must be between 0.0 and 1.0, got: #{alpha}",
                   fn ->
                     Curves.define_centripetal_catmull_rom(@bunched, alpha: alpha)
                   end
    end

    assert_raise ArgumentError, "the :alpha option must be a number, got: :centripetal", fn ->
      Curves.define_centripetal_catmull_rom(@bunched, alpha: :centripetal)
    end
  end
end
