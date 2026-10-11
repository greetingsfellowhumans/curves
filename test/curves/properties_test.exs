defmodule Curves.PropertiesTest do
  # Mathematical properties of the public API, checked on random curves.
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Transform

  # A coordinate in -100..100.
  @spec coord() :: StreamData.t(float())
  defp coord, do: StreamData.float(min: -100.0, max: 100.0)

  @spec point() :: StreamData.t({float(), float()})
  defp point, do: StreamData.tuple({coord(), coord()})

  @spec points(pos_integer(), pos_integer()) :: StreamData.t(list({float(), float()}))
  defp points(min, max), do: StreamData.list_of(point(), min_length: min, max_length: max)

  @spec bezier() :: StreamData.t(Curves.Bezier.Curve.t())
  defp bezier, do: StreamData.map(points(2, 4), &Curves.define_bezier/1)

  # Every spline type, from 4 to 8 points. A bezier spline gets a control point either side of each
  # knot, and a Hermite spline a tangent at each knot.
  @spec spline() :: StreamData.t(Curves.Spline.Curve.t())
  defp spline do
    StreamData.bind(
      StreamData.member_of([:catmull_rom, :hermite, :b_spline, :bezier_spline]),
      fn
        :catmull_rom -> StreamData.map(points(4, 8), &Curves.define_catmull_rom/1)
        :hermite -> StreamData.map(points(4, 8), &hermite/1)
        :b_spline -> StreamData.map(points(4, 8), &Curves.define_b_spline/1)
        :bezier_spline -> StreamData.map(points(4, 8), &bezier_spline/1)
      end
    )
  end

  # A Hermite spline with tangents taken from each knot's own coordinates, so they vary.
  @spec hermite(list({float(), float()})) :: Curves.Spline.Curve.t()
  defp hermite(knots),
    do: knots |> Enum.map(fn {x, y} -> [{x, y}, {y / 2, -x / 2}] end) |> Curves.define_hermite()

  # Every knot but the last gets the two control points of the curve to the next knot.
  @spec bezier_spline(list({float(), float()})) :: Curves.Spline.Curve.t()
  defp bezier_spline(knots) do
    {curves, [last]} = Enum.split(knots, -1)

    curves
    |> Enum.map(fn {x, y} -> [{x, y}, {x + 1.0, y - 2.0}, {x - 1.0, y + 2.0}] end)
    |> Kernel.++([[last]])
    |> Curves.define_bezier_spline()
  end

  @spec curve() :: StreamData.t(Curves.Types.curve_struct())
  # A polyline of 2 to 8 knots.
  @spec polyline() :: StreamData.t(Curves.Polyline.Curve.t())
  defp polyline, do: StreamData.map(points(2, 8), &Curves.define_polyline/1)

  defp curve, do: StreamData.one_of([bezier(), spline(), polyline()])

  # A fraction of the way along a curve, 0.0..1.0.
  @spec fraction() :: StreamData.t(float())
  defp fraction, do: StreamData.float(min: 0.0, max: 1.0)

  @spec assert_near({float(), float()}, {float(), float()}, float()) :: true
  defp assert_near({ax, ay}, {bx, by}, tolerance) do
    assert abs(ax - bx) <= tolerance and abs(ay - by) <= tolerance,
           "#{inspect({ax, ay})} is not within #{tolerance} of #{inspect({bx, by})}"
  end

  # Each point but the last is a line, a quadratic or a cubic to the next knot (SVG L, Q or C).
  property "a bezier spline passes through every knot, at u = 0, 1, 2, ..." do
    check all(knots <- points(1, 8), offset <- point(), controls <- StreamData.integer(0..2)) do
      {curves, [last]} = Enum.split(knots, -1)

      curve =
        curves
        |> Enum.map(fn knot ->
          [knot | List.duplicate(Curves.Utils.Vec.add(knot, offset), controls)]
        end)
        |> Kernel.++([[last]])
        |> Curves.define_bezier_spline()

      for {knot, u} <- Enum.with_index(knots) do
        assert_near(Curves.solve!(curve, u * 1.0), knot, 1.0e-9)
      end
    end
  end

  property "a bezier starts at its first point and ends at its last" do
    check all(pts <- points(2, 4)) do
      curve = Curves.define_bezier(pts)
      assert_near(Curves.solve!(curve, 0.0), hd(pts), 1.0e-3)
      assert_near(Curves.solve!(curve, 1.0), List.last(pts), 1.0e-3)
    end
  end

  property "take!/3 returns n points, the last one at max_u" do
    check all(curve <- curve(), n <- StreamData.integer(1..30)) do
      points = Curves.take!(curve, n)
      assert length(points) == n
      assert_near(List.last(points), Curves.solve!(curve, Curves.max_u(curve)), 1.0e-6)
    end
  end

  property "solving outside 0..max_u is an error" do
    check all(curve <- curve(), extra <- StreamData.float(min: 0.01, max: 10.0)) do
      too_far = Curves.max_u(curve) + extra
      assert {:error, {:out_of_bounds, ^too_far}} = Curves.solve(curve, too_far)
    end
  end

  property "splines and polylines are continuous where segments meet" do
    check all(curve <- StreamData.one_of([spline(), polyline()])) do
      for boundary <- 1..(trunc(Curves.max_u(curve)) - 1)//1 do
        before = Curves.solve!(curve, boundary - 1.0e-7)
        after_ = Curves.solve!(curve, boundary + 1.0e-7)
        assert_near(before, after_, 0.05)
      end
    end
  end

  property "set_position shifts every point by the same amount" do
    check all(curve <- curve(), {dx, dy} <- point(), f <- fraction()) do
      u = f * Curves.max_u(curve)
      {x, y} = Curves.solve!(curve, u)

      assert_near(
        Curves.solve!(Transform.set_position(curve, {dx, dy}), u),
        {x + dx, y + dy},
        1.0e-3
      )
    end
  end

  property "set_scale scales every point about (0, 0)" do
    check all(curve <- curve(), k <- StreamData.float(min: -3.0, max: 3.0), f <- fraction()) do
      u = f * Curves.max_u(curve)
      {x, y} = Curves.solve!(curve, u)
      assert_near(Curves.solve!(Transform.set_scale(curve, k), u), {x * k, y * k}, 1.0e-2)
    end
  end

  # Transforms apply in scale, rotate, move order, so a curve stays at its position.
  property "a moved, scaled and rotated point is position + rotate(scale * point)" do
    check all(
            curve <- curve(),
            {px, py} <- point(),
            k <- StreamData.float(min: -3.0, max: 3.0),
            deg <- StreamData.float(min: -360.0, max: 360.0),
            f <- fraction()
          ) do
      u = f * Curves.max_u(curve)
      {x, y} = Curves.solve!(curve, u)
      a = deg * :math.pi() / 180
      sx = x * k
      sy = y * k

      expected =
        {px + sx * :math.cos(a) - sy * :math.sin(a), py + sx * :math.sin(a) + sy * :math.cos(a)}

      transformed =
        curve
        |> Transform.set_position({px, py})
        |> Transform.set_scale(k)
        |> Transform.set_rotation(deg)

      assert_near(Curves.solve!(transformed, u), expected, 1.0e-6)
    end
  end

  property "set_rotation keeps every point's distance from the origin" do
    check all(curve <- curve(), deg <- StreamData.float(min: -360.0, max: 360.0), f <- fraction()) do
      u = f * Curves.max_u(curve)
      {x, y} = Curves.solve!(curve, u)
      {rx, ry} = Curves.solve!(Transform.set_rotation(curve, deg), u)
      distance = :math.sqrt(x * x + y * y)
      assert abs(:math.sqrt(rx * rx + ry * ry) - distance) <= 1.0e-3 * max(1.0, distance)
    end
  end

  # Beziers, B-splines, bezier splines and Hermite splines stay inside their own (stored) points,
  # so force_percent stays in 0..1. Catmull-Rom can bend outside its knots, so it's left out.
  property "force_percent stays within 0..1 for curves that stay inside their points" do
    check all(
            curve <-
              StreamData.one_of([
                bezier(),
                StreamData.map(points(4, 8), &Curves.define_b_spline/1),
                StreamData.map(points(4, 8), &bezier_spline/1),
                StreamData.map(points(4, 8), &hermite/1)
              ]),
            f <- fraction()
          ) do
      {x, y} = Curves.solve!(curve, f * Curves.max_u(curve), force_percent: true)
      assert x >= -1.0e-4 and x <= 1.0001
      assert y >= -1.0e-4 and y <= 1.0001
    end
  end

  property "Svg.render draws samples + 1 points, all inside the image" do
    check all(curve <- curve(), samples <- StreamData.integer(1..60)) do
      svg = Curves.Svg.render(curve, samples: samples, width: 300, height: 200, padding: 10)
      [_, line] = Regex.run(~r/<polyline points="([^"]+)" fill="none" stroke="#1c7ed6"/, svg)

      pixels =
        for pair <- String.split(line, " "),
            do: pair |> String.split(",") |> Enum.map(&String.to_float/1)

      assert length(pixels) == samples + 1

      for [x, y] <- pixels do
        assert x >= 9.99 and x <= 290.01
        assert y >= 9.99 and y <= 190.01
      end
    end
  end

  property "Svg axes stay inside the image, with increasing labels" do
    check all(curve <- curve(), scale <- StreamData.float(min: 0.01, max: 1000.0)) do
      svg = Curves.Svg.render(Curves.Transform.set_scale(curve, scale), show_axes: true)

      for [_ | coords] <-
            Regex.scan(~r/<line x1="([^"]+)" y1="([^"]+)" x2="([^"]+)" y2="([^"]+)"/, svg),
          coord <- Enum.map(coords, &String.to_float/1) do
        assert coord >= 39.99 and coord <= 560.01
      end

      for anchor <- ["middle", "end"] do
        values =
          for [_, label] <- Regex.scan(~r/text-anchor="#{anchor}"[^>]*>([^<]+)</, svg),
              do: label |> Float.parse() |> elem(0)

        assert length(values) >= 2
        assert values == Enum.sort(values) and values == Enum.uniq(values)
      end
    end
  end

  property "a t that isn't a number raises an ArgumentError" do
    check all(curve <- curve(), t <- StreamData.term(), not is_number(t)) do
      assert_raise ArgumentError, ~r/(t|u) must be a number, got: /, fn ->
        Curves.solve(curve, t)
      end
    end
  end

  property "a point that isn't {x, y} with numbers raises an ArgumentError" do
    bad_point =
      StreamData.one_of([
        StreamData.term(),
        StreamData.tuple({StreamData.term(), StreamData.term()})
      ])

    check all(point <- bad_point, not match?({x, y} when is_number(x) and is_number(y), point)) do
      assert_raise ArgumentError, ~r/expected an \{x, y\} point with numbers, got: /, fn ->
        Curves.define_bezier([{0, 0}, point])
      end
    end
  end

  property "anything that isn't a curve raises an ArgumentError" do
    check all(bad <- StreamData.term()) do
      assert_raise ArgumentError,
                   ~r/expected a Curves.Bezier.Curve, Curves.Spline.Curve or Curves.Polyline.Curve/,
                   fn ->
                     Curves.solve(bad, 0.5)
                   end

      assert_raise ArgumentError,
                   ~r/expected a Curves.Bezier.Curve, Curves.Spline.Curve or Curves.Polyline.Curve/,
                   fn ->
                     Curves.take!(bad, 3)
                   end

      assert_raise ArgumentError,
                   ~r/expected a Curves.Bezier.Curve, Curves.Spline.Curve or Curves.Polyline.Curve/,
                   fn ->
                     Curves.Transform.inc_x(bad, 1)
                   end
    end
  end
end
