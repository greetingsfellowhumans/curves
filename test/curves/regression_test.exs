defmodule Curves.RegressionTest do
  use ExUnit.Case
  alias Curves.Types, as: T

  @spline_points [{5, 10}, {10, 5}, {15, 10}, {20, 10}, {25, 5}, {30, 15}]

  describe "spline u values" do
    test "a u within 0.0001 of the start is not rounded to the start" do
      curve = Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}])
      {x0, _} = Curves.solve!(curve, 0.0)
      {x, _} = Curves.solve!(curve, 1.0e-5)
      {x1, _} = Curves.solve!(curve, 1.0e-3)
      assert x > x0 and x < x1
    end

    test "a small negative u extends slightly before the start" do
      curve = Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}])
      {before_x, before_y} = Curves.solve!(curve, -0.0005)
      {after_x, after_y} = Curves.solve!(curve, 0.0005)
      assert before_x < 0.0 and after_x > 0.0
      assert before_y < 0.0 and after_y > 0.0
    end

    test "accept integers" do
      curve = Curves.define_catmull_rom(@spline_points)
      assert {:ok, {x, y}} = Curves.solve(curve, 1)
      assert {:ok, {^x, ^y}} = Curves.solve(curve, 1.0)
      assert Curves.solve!(curve, 1) == {x, y}
    end

    test "out of bounds returns the offending u, matching the bezier error shape" do
      curve = Curves.define_catmull_rom(@spline_points)
      assert Curves.solve(curve, 99.0) == {:error, {:out_of_bounds, 99.0}}
      assert Curves.solve(curve, 99) == {:error, {:out_of_bounds, 99}}

      bezier = Curves.define_bezier(:linear)
      assert Curves.solve(bezier, 2.0) == {:error, {:out_of_bounds, 2.0}}
    end

    test "solve! raises OutOfBoundU" do
      curve = Curves.define_catmull_rom(@spline_points)
      assert_raise Curves.Exceptions.OutOfBoundU, fn -> Curves.solve!(curve, 99) end
    end
  end

  describe "spline take/2" do
    # Float rounding used to push the final sample just past max_u, e.g. 3 * (3 / 187) * 187 > 3.0
    test "never overshoots the final segment" do
      known_overshoots = [{3, 187}, {3, 273}, {3, 275}]
      sweep = for segments <- 1..6, n <- 1..40, do: {segments, n}

      for {segments, n} <- known_overshoots ++ sweep do
        curve = Curves.define_catmull_rom(Enum.map(0..segments, &{&1, rem(&1, 2)}))
        assert {:ok, points} = Curves.take(curve, n), "#{segments} segments, n=#{n}"
        assert length(points) == n
      end
    end

    test "take! returns points" do
      curve = Curves.define_catmull_rom(@spline_points)
      assert length(Curves.take!(curve, 7)) == 7
    end

    test "n must be a positive integer" do
      spline = Curves.define_catmull_rom(@spline_points)
      bezier = Curves.define_bezier(:ease)

      for curve <- [spline, bezier], n <- [0, -1, 2.0, nil] do
        assert_raise ArgumentError, ~r/n must be a positive integer/, fn ->
          Curves.take(curve, n)
        end

        assert_raise ArgumentError, ~r/n must be a positive integer/, fn ->
          Curves.take!(curve, n)
        end
      end
    end

    test "a one-knot spline is a single point" do
      for curve <- [
            Curves.define_catmull_rom([{1, 2}]),
            Curves.define_bezier_spline([[{1, 2}]])
          ] do
        assert Curves.max_u(curve) == 1.0
        assert Curves.take!(curve, 3) == [{1.0, 2.0}, {1.0, 2.0}, {1.0, 2.0}]
      end
    end

    # A single knot is also the last point, which only ends the curve, so control points are an error.
    test "a one-knot bezier spline with control points raises" do
      for point <- [[{5, 5}, {0, 0}], [{5, 5}, {0, 0}, {10, 0}]] do
        assert_raise ArgumentError,
                     ~r/the last point of a bezier spline only ends the curve/,
                     fn ->
                       Curves.define_bezier_spline([point])
                     end
      end
    end
  end

  describe "force_percent" do
    test "bezier honours it when passed to define" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}], force_percent: true)
      assert Curves.solve!(curve, 1.0) == {1.0, 1.0}
      assert Curves.solve!(curve, 0.0) == {0.0, 0.0}
    end

    test "bezier honours it when passed to solve" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])
      assert Curves.solve!(curve, 1.0, force_percent: true) == {1.0, 1.0}
      assert Curves.solve!(curve, 1.0) == {40.0, 400.0}
    end

    test "spline honours it when passed to solve" do
      curve = Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}])
      {x, y} = Curves.solve!(curve, curve.max_u)
      assert {x, y} == {30.0, 100.0}
      {px, py} = Curves.solve!(curve, curve.max_u, force_percent: true)
      assert_in_delta px, 1.0, 0.001
      assert_in_delta py, 1.0, 0.001
    end
  end

  # Beziers read the app-wide :force_percent setting on every solve/take call, not at define time.
  # This module is not async, so changing the app env here can't leak into other tests.
  describe "force_percent app config" do
    setup do
      previous = Application.fetch_env(:curves, :force_percent)
      on_exit(fn -> restore_force_percent(previous) end)
    end

    test "bezier picks up a config change made after define" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])
      Application.put_env(:curves, :force_percent, true)
      assert Curves.solve!(curve, 1.0) == {1.0, 1.0}
      assert Curves.take!(curve, 2) == [{0.5, 0.5}, {1.0, 1.0}]
    end

    test "bezier stops rescaling when the config is turned off after define" do
      Application.put_env(:curves, :force_percent, true)
      curve = Curves.define_bezier([{10, 100}, {40, 400}])
      Application.put_env(:curves, :force_percent, false)
      assert Curves.solve!(curve, 1.0) == {40.0, 400.0}
      assert Curves.take!(curve, 2) == [{25.0, 250.0}, {40.0, 400.0}]
    end

    test "opts passed to solve and take beat the config" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])
      Application.put_env(:curves, :force_percent, true)
      assert Curves.solve!(curve, 1.0, force_percent: false) == {40.0, 400.0}
      assert Curves.take!(curve, 2, force_percent: false) == [{25.0, 250.0}, {40.0, 400.0}]
    end

    test "spline picks up a config change made after define" do
      curve = Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}])
      Application.put_env(:curves, :force_percent, true)
      assert Curves.solve!(curve, curve.max_u) == {1.0, 1.0}
      assert List.last(Curves.take!(curve, 3)) == {1.0, 1.0}
    end

    test "spline stops rescaling when the config is turned off after define" do
      Application.put_env(:curves, :force_percent, true)
      curve = Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}])
      Application.put_env(:curves, :force_percent, false)
      assert Curves.solve!(curve, curve.max_u) == {30.0, 100.0}
    end

    test "opts passed to spline solve and define beat the config" do
      curve =
        Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}], force_percent: false)

      Application.put_env(:curves, :force_percent, true)
      assert Curves.solve!(curve, curve.max_u) == {30.0, 100.0}
      assert Curves.solve!(curve, curve.max_u, force_percent: true) == {1.0, 1.0}
    end

    test "opts passed to define beat the config" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}], force_percent: false)
      Application.put_env(:curves, :force_percent, true)
      assert Curves.solve!(curve, 1.0) == {40.0, 400.0}
    end
  end

  # Puts the :force_percent app env back to how it was before the test.
  @spec restore_force_percent({:ok, term()} | :error) :: :ok
  defp restore_force_percent({:ok, value}),
    do: Application.put_env(:curves, :force_percent, value)

  defp restore_force_percent(:error), do: Application.delete_env(:curves, :force_percent)

  describe "force_percent on transformed splines" do
    @catmull_points [{0, 0}, {10, 100}, {20, 0}, {30, 100}]

    # Solves the start, middle and end of a spline with force_percent on.
    @spec ends(Curves.Spline.Curve.t()) :: list(T.point_tuple())
    defp ends(curve),
      do:
        Enum.map(
          [0.0, curve.max_u / 2, curve.max_u],
          &Curves.solve!(curve, &1, force_percent: true)
        )

    test "scaled spline uses transformed bounds" do
      curve = Curves.define_catmull_rom(@catmull_points) |> Curves.Transform.set_scale(2.0)
      assert ends(curve) == [{0.0, 0.0}, {0.5, 0.5}, {1.0, 1.0}]
    end

    test "moved spline uses transformed bounds" do
      curve = Curves.define_catmull_rom(@catmull_points) |> Curves.Transform.set_position({5, 5})
      assert ends(curve) == [{0.0, 0.0}, {0.5, 0.5}, {1.0, 1.0}]
    end

    test "origin option uses transformed bounds" do
      curve = Curves.define_catmull_rom(@catmull_points, origin: {7, 7})
      assert ends(curve) == [{0.0, 0.0}, {0.5, 0.5}, {1.0, 1.0}]
    end

    test "negative scale flips the percentages" do
      curve = Curves.define_catmull_rom(@catmull_points) |> Curves.Transform.set_scale(-1.5)
      assert ends(curve) == [{1.0, 1.0}, {0.5, 0.5}, {0.0, 0.0}]
    end

    test "rotated spline uses transformed bounds" do
      curve = Curves.define_catmull_rom(@catmull_points) |> Curves.Transform.set_rotation(90)
      [{x0, y0}, _mid, {x1, y1}] = ends(curve)
      assert {x0, y0, x1} == {1.0, 0.0, 0.0}
      assert_in_delta y1, 1.0, 1.0e-12
    end

    test "take! on a moved spline stays within 0..1" do
      curve =
        Curves.define_catmull_rom(@catmull_points) |> Curves.Transform.set_position({100, 100})

      for {x, y} <- Curves.take!(curve, 20, force_percent: true) do
        assert x >= 0.0 and x <= 1.0
        assert y >= 0.0 and y <= 1.0
      end
    end

    test "moved away and back gives the same result as never moving" do
      curve = Curves.define_catmull_rom(@catmull_points)

      moved_back =
        curve |> Curves.Transform.set_position({5, 5}) |> Curves.Transform.set_position({0, 0})

      assert ends(moved_back) == ends(curve)
    end

    test "the struct keeps the original points" do
      curve = Curves.define_catmull_rom(@catmull_points)
      moved = Curves.Transform.set_position(curve, {5, 5})
      assert moved.points == curve.points
    end
  end

  describe "force_percent on transformed beziers" do
    @line [{10, 100}, {40, 400}]

    test "moved bezier uses transformed bounds" do
      curve = Curves.define_bezier(@line) |> Curves.Transform.set_position({5, 5})
      assert Curves.solve!(curve, 0.5, force_percent: true) == {0.5, 0.5}
    end

    test "origin option uses transformed bounds" do
      curve = Curves.define_bezier([{0, 0}, {1, 1}], origin: {10, 10})
      assert Curves.solve!(curve, 1.0, force_percent: true) == {1.0, 1.0}
    end

    test "rotated bezier uses transformed bounds" do
      curve = Curves.define_bezier(:linear_up_right) |> Curves.Transform.set_rotation(90)
      assert Curves.solve!(curve, 1.0, force_percent: true) == {0.0, 1.0}
    end

    test "inc_scale uses transformed bounds" do
      curve = Curves.define_bezier(@line) |> Curves.Transform.inc_scale(1.0)
      assert Curves.solve!(curve, 0.5, force_percent: true) == {0.5, 0.5}
    end

    test "negative scale flips the percentages" do
      curve = Curves.define_bezier(@line) |> Curves.Transform.set_scale(-2.0)
      assert Curves.solve!(curve, 0.0, force_percent: true) == {1.0, 1.0}
      assert Curves.solve!(curve, 1.0, force_percent: true) == {0.0, 0.0}
    end

    test "take! on a moved cubic stays within 0..1" do
      curve =
        Curves.define_bezier([{0, 0}, {1, 3}, {2, -1}, {3, 1}])
        |> Curves.Transform.set_position({50, 50})

      for {x, y} <- Curves.take!(curve, 20, force_percent: true) do
        assert x >= 0.0 and x <= 1.0
        assert y >= 0.0 and y <= 1.0
      end
    end

    test "moved away and back gives the same result as never moving" do
      curve = Curves.define_bezier(@line)

      moved_back =
        curve |> Curves.Transform.set_position({5, 5}) |> Curves.Transform.set_position({0, 0})

      assert Curves.solve!(moved_back, 0.25, force_percent: true) ==
               Curves.solve!(curve, 0.25, force_percent: true)
    end

    test "transforming a bezier with too few points still defers the error to solve" do
      curve = Curves.define_bezier([{1, 1}]) |> Curves.Transform.set_position({5, 5})
      assert Curves.solve(curve, 0.5, force_percent: true) == {:error, {:too_few_points, 1, 2}}
    end
  end

  # Pins down current outputs, including known oddities (flat ranges returning 0.5,
  # rotation noise on flat curves), so refactors can't change them silently.
  describe "force_percent characterization" do
    # Rotating adds float noise (y becomes -1.0000000000000002 and -0.9999999999999999), so the flat
    # y axis is no longer flat and gets rescaled over 0..1. Left as-is on purpose: see the :force_percent docs.
    test "rotated flat curve rescales its float noise" do
      curve = Curves.define_bezier(:linear_horizontal) |> Curves.Transform.set_rotation(180)
      assert Curves.solve!(curve, 0.0, force_percent: true) == {1.0, 0.0}
      assert Curves.solve!(curve, 1.0, force_percent: true) == {0.0, 1.0}
    end

    test "flat range returns 0.5" do
      curve = Curves.define_bezier(:linear_horizontal)
      assert Curves.solve!(curve, 0.5, force_percent: true) == {0.5, 0.5}
    end

    test "any truthy value turns it on" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])
      assert Curves.solve!(curve, 1.0, force_percent: 1) == {1.0, 1.0}
    end
  end

  describe "spline types" do
    test "an unknown spline type raises with its name" do
      assert_raise ArgumentError, "Unknown spline_type: :wavy", fn ->
        Curves.Spline.TypeIndex.get(:wavy)
      end
    end

    test "every type key maps to its module, and a {:module, mod} passes straight through" do
      assert Curves.Spline.Type.list() == [:b_spline, :bezier_spline, :catmull_rom, :hermite]

      for key <- Curves.Spline.Type.list() do
        mod = Curves.Spline.Type.get_mod(key)
        assert [[_, _, _, _], [_, _, _, _], [_, _, _, _], [_, _, _, _]] = mod.blending_function()
      end

      assert Curves.Spline.TypeIndex.get({:module, Curves.Spline.Type.Hermite}) ==
               Curves.Spline.Type.Hermite
    end

    test "too few points raise an ArgumentError, not a crash deep inside" do
      assert_raise ArgumentError, ~r/at least 1 point/, fn -> Curves.define_catmull_rom([]) end
      assert_raise ArgumentError, ~r/at least 1 point/, fn -> Curves.define_bezier_spline([]) end
      assert_raise ArgumentError, ~r/at least 2 points/, fn -> Curves.define_hermite([]) end
      assert_raise ArgumentError, ~r/at least one point/, fn -> Curves.define_bezier([]) end

      for n <- 0..3 do
        points = Enum.take([{0, 0}, {1, 1}, {2, 0}], n)

        assert_raise ArgumentError, "a B-spline needs at least 4 points, got #{n}", fn ->
          Curves.define_b_spline(points)
        end
      end

      assert Curves.max_u(Curves.define_b_spline([{0, 0}, {1, 1}, {2, 0}, {3, 1}])) == 1.0
    end
  end

  describe "bezier take/3" do
    # It used to sample at i * (1 / n), and the rounding in 1 / n left the last t at
    # 0.9999999999999999 for some n, e.g. 49.
    test "the last sample is exactly the end of the curve" do
      curve = Curves.define_bezier([{0, 0}, {1, 3}, {2, -1}, {3, 1}])
      last = Curves.solve!(curve, 1.0)

      for n <- 1..500 do
        assert List.last(Curves.take!(curve, n)) == last, "n=#{n}"
      end
    end
  end

  describe "bezier point count" do
    test "more than 4 points returns an error instead of crashing" do
      curve = Curves.define_bezier([{0, 0}, {1, 1}, {2, 0}, {3, 1}, {4, 0}])
      assert Curves.solve(curve, 0.5) == {:error, {:too_many_points, 5, 4}}
      assert Curves.take(curve, 3) == {:error, {:too_many_points, 5, 4}}
      assert_raise Curves.Exceptions.TooManyPoints, fn -> Curves.solve!(curve, 0.5) end
      assert_raise Curves.Exceptions.TooManyPoints, fn -> Curves.take!(curve, 3) end
    end

    test "fewer than 2 points can be defined and transformed, but not solved" do
      curve = Curves.define_bezier([{0, 0}]) |> Curves.Transform.set_scale(2.0)
      assert Curves.solve(curve, 0.5) == {:error, {:too_few_points, 1, 2}}
      assert_raise Curves.Exceptions.TooFewPoints, fn -> Curves.solve!(curve, 0.5) end
    end
  end

  describe "not a curve" do
    # A struct of another type, and a plain map with the fields a curve has.
    @not_curves [
      :nope,
      nil,
      [{0, 0}, {1, 1}],
      %{},
      %{origin: {0.0, 0.0}, scale: 1.0, rotation: 0.0},
      URI.parse("https://example.com")
    ]

    # Every public function that takes a curve, called with `bad` in its place.
    @spec calls(term()) :: list((-> term()))
    defp calls(bad) do
      [
        fn -> Curves.solve(bad, 0.5) end,
        fn -> Curves.solve!(bad, 0.5) end,
        fn -> Curves.take(bad, 3) end,
        fn -> Curves.take!(bad, 3) end,
        fn -> Curves.Transform.set_position(bad, {1, 1}) end,
        fn -> Curves.Transform.inc_position(bad, {1, 1}) end,
        fn -> Curves.Transform.inc_x(bad, 1) end,
        fn -> Curves.Transform.inc_y(bad, 1) end,
        fn -> Curves.Transform.set_scale(bad, 2) end,
        fn -> Curves.Transform.inc_scale(bad, 2) end,
        fn -> Curves.Transform.set_rotation(bad, 90) end,
        fn -> Curves.Transform.inc_rotation(bad, 90) end,
        fn -> Curves.Svg.render(bad) end,
        fn -> Curves.Svg.render(bad, show_points: true, samples: 3) end
      ]
    end

    test "raises an ArgumentError naming the curve types and the bad value" do
      for bad <- @not_curves, call <- calls(bad) do
        error = assert_raise ArgumentError, call

        assert error.message ==
                 "expected a Curves.Bezier.Curve, Curves.Spline.Curve or Curves.Polyline.Curve, got: #{inspect(bad)}"
      end
    end

    test "take/3 checks n before the curve" do
      assert_raise ArgumentError, ~r/n must be a positive integer/, fn ->
        Curves.take(:nope, 0)
      end

      assert_raise ArgumentError, ~r/n must be a positive integer/, fn ->
        Curves.take!(:nope, 0)
      end
    end
  end

  describe "clear errors" do
    test "an unknown predefined curve" do
      for name <- [:nope, nil] do
        assert_raise ArgumentError,
                     ~r/unknown predefined curve: #{inspect(name)}\. See Curves.Bezier.Predefined.list\/0/,
                     fn ->
                       Curves.define_bezier(name)
                     end
      end

      assert_raise ArgumentError, ~r/unknown predefined curve: :nope/, fn ->
        Curves.Bezier.Predefined.details(:nope)
      end

      assert_raise ArgumentError, ~r/unknown predefined curve: :nope/, fn ->
        Curves.Bezier.Predefined.get_coords(:nope)
      end
    end

    test "a bad order for Predefined.list/1" do
      assert_raise ArgumentError, "order must be 1, 2, 3, :linear, :quad or :cubic, got: 4", fn ->
        Curves.Bezier.Predefined.list(4)
      end
    end

    test "define_bezier with something that isn't a list of points" do
      for bad <- ["x", %{}, {1, 2}] do
        assert_raise ArgumentError, ~r/a bezier curve takes a list of \{x, y\} points/, fn ->
          Curves.define_bezier(bad)
        end
      end
    end

    test "a point that isn't {x, y} with numbers, in any define or transform" do
      calls = [
        fn -> Curves.define_bezier([{0, 0}, {1, :a}]) end,
        fn -> Curves.define_bezier([{0, 0}, [1, 1]]) end,
        fn -> Curves.define_bezier([{0, 0}, {1, 1}], origin: :here) end,
        fn -> Curves.define_catmull_rom([{0, 0}, {1, 1}, "x"]) end,
        fn -> Curves.define_b_spline([{0, 0}, {1, 1}, {2, 2}, {3, nil}]) end,
        fn -> Curves.define_b_spline([{0, 0}, {1, 1}, {2, 2}, 3]) end,
        fn -> Curves.define_bezier_spline([[{0, 0}], [1]]) end,
        fn -> Curves.define_hermite([[{0, 0}, {1, 1}], [{1, :a}, {1, 1}]]) end,
        fn -> Curves.Transform.set_position(Curves.define_bezier(:linear), {1, "2"}) end,
        fn -> Curves.Transform.inc_position(Curves.define_bezier(:linear), 5) end
      ]

      for call <- calls do
        assert_raise ArgumentError, ~r/expected an \{x, y\} point with numbers, got: /, call
      end
    end

    test "a t or u that isn't a number" do
      assert_raise ArgumentError, "t must be a number, got: :x", fn ->
        Curves.solve(Curves.define_bezier(:linear), :x)
      end

      assert_raise ArgumentError, ~s(u must be a number, got: "1"), fn ->
        Curves.solve!(Curves.define_catmull_rom(@spline_points), "1")
      end
    end

    test "a transform amount that isn't a number" do
      curve = Curves.define_bezier(:linear)

      for fun <- [:inc_x, :inc_y] do
        assert_raise ArgumentError, "Curves.Transform.#{fun}/2 needs a number, got: :a", fn ->
          apply(Curves.Transform, fun, [curve, :a])
        end
      end

      for fun <- [:set_rotation, :inc_rotation] do
        assert_raise ArgumentError, "Curves.Transform.#{fun}/3 needs a number, got: :a", fn ->
          apply(Curves.Transform, fun, [curve, :a])
        end
      end

      # A scale can also be an {x, y} pair.
      for fun <- [:set_scale, :inc_scale], bad <- [:a, {1, :a}, {1, 2, 3}] do
        message =
          "Curves.Transform.#{fun}/3 needs a number or an {x, y} pair of numbers, got: #{inspect(bad)}"

        assert_raise ArgumentError, message, fn -> apply(Curves.Transform, fun, [curve, bad]) end
      end
    end

    test "a bad :around option" do
      curve = Curves.define_bezier(:linear)

      for bad <- [:middle, {1, :a}, 5] do
        assert_raise ArgumentError, ~r/:around must be :center or an \{x, y\} point/, fn ->
          Curves.Transform.set_rotation(curve, 90, around: bad)
        end
      end

      assert_raise ArgumentError, ~r/expected a keyword list of options/, fn ->
        Curves.Transform.flip_x(curve, :center)
      end
    end

    test "Svg's show_* options treat nil like false" do
      curve = Curves.define_bezier(:linear)
      svg = Curves.Svg.render(curve, show_points: nil, show_polygon: nil, show_axes: nil)
      refute svg =~ "<circle"
      refute svg =~ "stroke-dasharray"
      refute svg =~ "<line"
    end
  end
end
