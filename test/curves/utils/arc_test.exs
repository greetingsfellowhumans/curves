defmodule Curves.Utils.ArcTest do
  use ExUnit.Case, async: true
  alias Curves.Utils.Arc

  @bezier [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  # Solves an arc, or a 4-point (Bezier) segment, at t, the way the spline engine does.
  @spec at(Arc.t() | list({float(), float()}), float()) :: {float(), float()}
  defp at(segment, t) when is_list(segment),
    do: @bezier |> Curves.Utils.Poly.coefficients(segment) |> Curves.Utils.Poly.eval(t)

  defp at(arc, t), do: arc |> Arc.prepare() |> Arc.eval(t)

  @spec assert_near({float(), float()}, {float(), float()}, float()) :: true
  defp assert_near({ax, ay}, {bx, by}, tolerance \\ 1.0e-9) do
    assert abs(ax - bx) <= tolerance and abs(ay - by) <= tolerance,
           "#{inspect({ax, ay})} is not near #{inspect({bx, by})}"
  end

  describe "from_svg/3" do
    # A circle of radius 10 through {0, 0} and {10, 0} has its centre at {5, ±8.66}. The flags
    # pick one of the four arcs between them, like SVG.
    test "the large_arc and sweep flags pick one of four arcs" do
      depth = 10 - :math.sqrt(75)

      for {large_arc, sweep, middle} <- [
            {false, true, {5.0, -depth}},
            {true, true, {5.0, -20 + depth}},
            {false, false, {5.0, depth}},
            {true, false, {5.0, 20 - depth}}
          ] do
        arc = Arc.from_svg({0.0, 0.0}, {10, 10, 0, large_arc, sweep}, {10.0, 0.0})
        assert at(arc, 0.0) == {0.0, 0.0}
        assert at(arc, 1.0) == {10.0, 0.0}
        assert_near(at(arc, 0.5), middle)
      end
    end

    test "sweep true turns the angle up (anticlockwise with y up), false turns it down" do
      {:arc, _c, _a, _b, from, to, _, _} =
        Arc.from_svg({0.0, 0.0}, {10, 10, 0, false, true}, {10.0, 0.0})

      assert to > from

      {:arc, _c, _a, _b, from, to, _, _} =
        Arc.from_svg({0.0, 0.0}, {10, 10, 0, false, false}, {10.0, 0.0})

      assert to < from
    end

    test "radii too small to reach are scaled up, giving a half ellipse" do
      arc = Arc.from_svg({0.0, 0.0}, {1, 1, 0, false, true}, {10.0, 0.0})
      assert_near(at(arc, 0.5), {5.0, -5.0})

      # Squashed 2:1, scaled up together
      arc = Arc.from_svg({0.0, 0.0}, {2, 1, 0, false, true}, {10.0, 0.0})
      assert_near(at(arc, 0.5), {5.0, -2.5})
    end

    test "negative radii count as positive" do
      assert Arc.from_svg({0.0, 0.0}, {-5, -5, 0, false, true}, {10.0, 0.0}) ==
               Arc.from_svg({0.0, 0.0}, {5, 5, 0, false, true}, {10.0, 0.0})
    end

    test "a rotated ellipse: every point is on it" do
      arc = Arc.from_svg({0.0, 0.0}, {8, 3, 30, true, false}, {6.0, 4.0})
      {:arc, c, a, b, _from, _to, _, _} = arc
      {cx, cy} = c
      {rx, ry} = {distance(a, c), distance(b, c)}
      phi = 30 * :math.pi() / 180

      for i <- 0..20 do
        {x, y} = at(arc, i / 20)
        # Turn the point back into the ellipse's own axes.
        {dx, dy} = {x - cx, y - cy}

        {u, v} =
          {:math.cos(phi) * dx + :math.sin(phi) * dy, -:math.sin(phi) * dx + :math.cos(phi) * dy}

        assert_in_delta u * u / (rx * rx) + v * v / (ry * ry), 1.0, 1.0e-9
      end
    end

    test "the same start and end stays put, and a zero radius is a straight line" do
      assert Arc.from_svg({1.0, 2.0}, {5, 5, 0, true, true}, {1.0, 2.0}) ==
               [{1.0, 2.0}, {1.0, 2.0}, {1.0, 2.0}, {1.0, 2.0}]

      for spec <- [{0, 5, 0, false, true}, {5, 0, 0, false, true}] do
        line = Arc.from_svg({0.0, 0.0}, spec, {6.0, 3.0})
        assert is_list(line)
        assert_near(at(line, 1 / 3), {2.0, 1.0})
      end
    end

    test "radii far too small or far too big are a straight line, without overflowing" do
      for r <- [1.0e-300, 1.0e-200, 1.0e-120, 1.0e11, 1.0e120, 1.0e300] do
        segment = Arc.from_svg({0.0, 0.0}, {r, r, 0, false, true}, {10.0, 0.0})
        {x, y} = at(segment, 0.5)
        assert_in_delta x, 5.0, 1.0e-6
        assert_in_delta y, 0.0, 1.0e-6
      end
    end

    test "a huge radius that is still an arc stays accurate" do
      # Radius 1e8 over a distance of 10: the arc bulges 10² / (8 * 1e8) = 1.25e-7 from the line.
      arc = Arc.from_svg({0.0, 0.0}, {1.0e8, 1.0e8, 0, false, true}, {10.0, 0.0})
      assert {:arc, _, _, _, _, _, _, _} = arc
      {x, y} = at(arc, 0.5)
      assert_in_delta x, 5.0, 1.0e-6
      assert_in_delta y, -1.25e-7, 1.0e-7
    end
  end

  describe "new/5 and ellipse/6" do
    test "a whole turn ends exactly where it starts" do
      for turns <- [1, 2, -1] do
        arc = Arc.ellipse({1.0, 2.0}, 4.0, 2.0, 0.3, 0.1, 0.1 + turns * 2 * :math.pi())
        assert at(arc, 1.0) == at(arc, 0.0)
      end
    end

    test "rotation tilts the x axis" do
      arc = Arc.ellipse({0.0, 0.0}, 4.0, 2.0, :math.pi() / 2, 0.0, :math.pi())
      assert_near(at(arc, 0.0), {0.0, 4.0})
      assert_near(at(arc, 0.5), {-2.0, 0.0})
    end
  end

  test "reverse/1 swaps the ends, and map_points/2 moves every point" do
    arc = Arc.ellipse({0.0, 0.0}, 2.0, 2.0, 0.0, 0.0, :math.pi() / 2)
    reversed = Arc.reverse(arc)
    assert_near(at(reversed, 0.25), at(arc, 0.75))

    moved = Arc.map_points(arc, &Curves.Utils.Vec.add(&1, {10.0, 0.0}))
    assert_near(at(moved, 0.5), Curves.Utils.Vec.add(at(arc, 0.5), {10.0, 0.0}))
  end

  describe "hull_points/1 and hull_lines/1" do
    test "a quarter circle: its ends and the corner where their tangents meet" do
      arc = Arc.ellipse({0.0, 0.0}, 1.0, 1.0, 0.0, 0.0, :math.pi() / 2)
      [start, corner, finish] = Arc.hull_points(arc)
      assert start == {1.0, 0.0}
      assert_near(corner, {1.0, 1.0})
      assert_near(finish, {0.0, 1.0})
      assert [[^start, ^corner, ^finish]] = Arc.hull_lines(arc)
    end

    test "a whole ellipse: the box around it, so its middle is the centre" do
      arc = Arc.ellipse({3.0, 1.0}, 4.0, 2.0, 0.0, 0.0, 2 * :math.pi())
      points = Arc.hull_points(arc)
      assert length(points) == 9
      bounds = Curves.Utils.Vec.bounds(points)
      assert_in_delta bounds.xmin, -1.0, 1.0e-9
      assert_in_delta bounds.xmax, 7.0, 1.0e-9
      assert_in_delta bounds.ymin, -1.0, 1.0e-9
      assert_in_delta bounds.ymax, 3.0, 1.0e-9
      assert length(Arc.hull_lines(arc)) == 4
    end

    test "an arc of no angle at all has one piece and doesn't divide by zero" do
      arc = Arc.ellipse({0.0, 0.0}, 1.0, 1.0, 0.0, 1.0, 1.0)
      assert length(Arc.hull_points(arc)) == 3
    end
  end

  @spec distance({float(), float()}, {float(), float()}) :: float()
  defp distance({ax, ay}, {bx, by}), do: :math.sqrt((ax - bx) ** 2 + (ay - by) ** 2)
end
