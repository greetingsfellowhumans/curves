defmodule Curves.Spline.MonotoneTest do
  use ExUnit.Case, async: true

  @data [{0, 0}, {1, 0}, {2, 3}, {3, 3}, {4, 1}]

  # Checks two points are equal to within float rounding.
  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  test "passes through every data point, and x moves at a steady speed" do
    curve = Curves.define_monotone(@data)
    assert Curves.max_u(curve) == 4.0

    for {{x, y}, i} <- Enum.with_index(@data),
        do: assert_near(Curves.solve!(curve, i * 1.0), {x * 1.0, y * 1.0})

    for u <- [0.25, 1.5, 2.75, 3.1],
        do: assert_in_delta(elem(Curves.solve!(curve, u), 0), u, 1.0e-12)
  end

  test "stays flat where the data is flat, and never overshoots" do
    curve = Curves.define_monotone(@data)
    assert_near(Curves.solve!(curve, 0.5), {0.5, 0.0})
    assert_near(Curves.solve!(curve, 2.5), {2.5, 3.0})

    # Catmull-Rom dips below 0 and swings above 3 with the same data.
    catmull_rom = Curves.define_catmull_rom(@data)
    ys = fn curve -> for i <- 0..400, do: elem(Curves.solve!(curve, i / 100), 1) end
    {low, high} = Enum.min_max(ys.(catmull_rom))
    assert low < 0.0 or high > 3.0
    assert Enum.min_max(ys.(curve)) == {0.0, 3.0}
  end

  test "steep data next to gentle data still doesn't overshoot" do
    # The middle jump is far steeper than its neighbours, so the slopes get scaled down.
    data = [{0, 0}, {1, 0.1}, {1.1, 5}, {2, 5.1}, {3, 5.2}]
    curve = Curves.define_monotone(data)

    data
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.each(fn {[{_, y0}, {_, y1}], i} ->
      for step <- 0..50 do
        {_x, y} = Curves.solve!(curve, i + step / 50)
        assert y >= y0 - 1.0e-12 and y <= y1 + 1.0e-12
      end
    end)
  end

  test "x can always decrease instead" do
    curve = Curves.define_monotone(Enum.reverse(@data))
    assert_near(Curves.solve!(curve, 1.5), {2.5, 3.0})
    assert_near(Curves.solve!(curve, 4.0), {0.0, 0.0})
  end

  test "one data point stays put and two make a straight line" do
    assert Curves.take!(Curves.define_monotone([{1, 2}]), 2) == [{1.0, 2.0}, {1.0, 2.0}]
    assert_near(Curves.solve!(Curves.define_monotone([{0, 0}, {4, 2}]), 0.25), {1.0, 0.5})
  end

  test "stores the data points as its points" do
    curve = Curves.define_monotone(@data)
    assert curve.points == Enum.map(@data, fn {x, y} -> {x * 1.0, y * 1.0} end)
    assert curve.type == :monotone
  end

  test "x that doesn't always go the same way raises an ArgumentError" do
    for bad <- [[{0, 0}, {1, 1}, {1, 2}], [{0, 0}, {2, 1}, {1, 2}], [{3, 0}, {2, 1}, {2.5, 0}]] do
      assert_raise ArgumentError,
                   ~r/the knots of a monotone spline must have x always increasing/,
                   fn ->
                     Curves.define_monotone(bad)
                   end
    end

    assert_raise ArgumentError, "a spline needs at least 1 point, got none", fn ->
      Curves.define_monotone([])
    end

    assert_raise ArgumentError, ~r/expected an {x, y} point with numbers/, fn ->
      Curves.define_monotone([{0, 0}, [1, 1]])
    end
  end
end
