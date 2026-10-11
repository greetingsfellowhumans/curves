defmodule Curves.RegressionTest do
  use ExUnit.Case
  alias Curves.Utils.Types, as: T

  @spline_points [{5, 10}, {10, 5}, {15, 10}, {20, 10}, {25, 5}, {30, 15}]

  describe "default precision" do
    test "defaults to f32" do
      curve = Curves.define_bezier([{0, 0}, {1000.123, 1}])
      assert Nx.type(curve.points) == {:f, 32}
      {x, _y} = Curves.solve!(curve, 0.5)
      assert_in_delta x, 500.0615, 0.001
    end

    test "float_dtype: 16 is still respected" do
      curve = Curves.define_bezier([{0, 0}, {1000.123, 1}], float_dtype: 16)
      assert Nx.type(curve.points) == {:f, 16}
    end
  end

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
      curve = Curves.define_hermite(@spline_points)
      assert {:ok, {x, y}} = Curves.solve(curve, 1)
      assert {:ok, {^x, ^y}} = Curves.solve(curve, 1.0)
      assert Curves.solve!(curve, 1) == {x, y}
    end

    test "out of bounds returns the offending u, matching the bezier error shape" do
      curve = Curves.define_hermite(@spline_points)
      assert Curves.solve(curve, 99.0) == {:error, {:out_of_bounds, 99.0}}
      assert Curves.solve(curve, 99) == {:error, {:out_of_bounds, 99}}

      bezier = Curves.define_bezier(:linear)
      assert Curves.solve(bezier, 2.0) == {:error, {:out_of_bounds, 2.0}}
    end

    test "solve! raises OutOfBoundU" do
      curve = Curves.define_hermite(@spline_points)
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
      curve = Curves.define_hermite(@spline_points)
      assert length(Curves.take!(curve, 7)) == 7
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

    # Splines read the config when defined or transformed, unlike beziers. Documented in the Curves moduledoc.
    test "spline only picks up a config change when defined or transformed again" do
      points = [{0, 0}, {10, 100}, {20, 0}, {30, 100}]
      curve = Curves.define_catmull_rom(points)
      Application.put_env(:curves, :force_percent, true)
      assert Curves.solve!(curve, curve.max_u) == {30.0, 100.0}

      redefined = Curves.define_catmull_rom(points)
      assert Curves.solve!(redefined, redefined.max_u) == {1.0, 1.0}

      transformed = Curves.Transform.set_position(curve, {0, 0})
      assert Curves.solve!(transformed, transformed.max_u) == {1.0, 1.0}
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
      assert {x0, y0, x1, y1} == {1.0, 0.0, 0.0, 1.0}
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
      assert Nx.to_list(moved.points) == Nx.to_list(curve.points)
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

  # Pins down current outputs, including known oddities (flat ranges returning max,
  # rotation noise on flat curves), so refactors can't change them silently.
  describe "force_percent characterization" do
    # Rotating adds float noise (y becomes -1.0 and -1.0000001), so the flat y axis is no
    # longer flat and gets rescaled over 0..1. Left as-is on purpose: see the :force_percent docs.
    test "rotated flat curve rescales its float noise" do
      curve = Curves.define_bezier(:linear_horizontal) |> Curves.Transform.set_rotation(180)
      assert Curves.solve!(curve, 0.0, force_percent: true) == {1.0, 1.0}
      assert Curves.solve!(curve, 1.0, force_percent: true) == {0.0, 0.0}
    end

    test "flat range returns max" do
      curve = Curves.define_bezier(:linear_horizontal)
      assert Curves.solve!(curve, 0.5, force_percent: true) == {0.5, 1.0}
    end

    test "any truthy value turns it on" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}])
      assert Curves.solve!(curve, 1.0, force_percent: 1) == {1.0, 1.0}
    end
  end

  describe "bezier point count" do
    test "more than 4 points returns an error instead of tensors" do
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
end
