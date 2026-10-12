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
  # knot, and a Hermite spline a tangent at each knot. A monotone spline's knots are data points.
  @spec spline() :: StreamData.t(Curves.Spline.Curve.t())
  defp spline do
    StreamData.bind(
      StreamData.member_of([
        :catmull_rom,
        :hermite,
        :b_spline,
        :bezier_spline,
        :cardinal,
        :centripetal_catmull_rom,
        :kochanek_bartels,
        :monotone,
        :natural_cubic,
        :arc_path,
        :ellipse
      ]),
      fn
        :catmull_rom -> StreamData.map(points(4, 8), &Curves.define_catmull_rom/1)
        :hermite -> StreamData.map(points(4, 8), &hermite/1)
        :b_spline -> StreamData.map(points(4, 8), &Curves.define_b_spline/1)
        :bezier_spline -> StreamData.map(points(4, 8), &bezier_spline/1)
        :cardinal -> cardinal(points(4, 8))
        :centripetal_catmull_rom -> centripetal(points(4, 8))
        :kochanek_bartels -> kochanek_bartels(points(4, 8))
        :monotone -> StreamData.map(data_points(4, 8), &Curves.define_monotone/1)
        :natural_cubic -> StreamData.map(points(4, 8), &Curves.define_natural_cubic/1)
        :arc_path -> arc_path(4, 8)
        :ellipse -> ellipse()
      end
    )
  end

  # An SVG arc command without its end point: radii 0..50, a rotation, and the two flags.
  @spec arc_spec() :: StreamData.t(tuple())
  defp arc_spec do
    StreamData.map(
      StreamData.tuple({
        StreamData.float(min: 0.0, max: 50.0),
        StreamData.float(min: 0.0, max: 50.0),
        StreamData.float(min: -360.0, max: 360.0),
        StreamData.boolean(),
        StreamData.boolean()
      }),
      fn {rx, ry, rotation, large_arc, sweep} -> {:arc, rx, ry, rotation, large_arc, sweep} end
    )
  end

  # A bezier spline whose curves are a mix of lines, cubics and arcs (SVG L, C and A).
  @spec arc_path(pos_integer(), pos_integer()) :: StreamData.t(Curves.Spline.Curve.t())
  defp arc_path(min, max) do
    StreamData.bind(points(min, max), fn knots ->
      {curves, [last]} = Enum.split(knots, -1)

      curves
      |> Enum.map(&path_point/1)
      |> StreamData.fixed_list()
      |> StreamData.map(&Curves.define_bezier_spline(&1 ++ [[last]]))
    end)
  end

  # One knot of a path, with a line, a cubic or an arc to the next one.
  @spec path_point({float(), float()}) :: StreamData.t(list())
  defp path_point({x, y} = knot) do
    StreamData.one_of([
      StreamData.constant([knot]),
      StreamData.constant([knot, {x + 1.0, y - 2.0}, {x - 1.0, y + 2.0}]),
      StreamData.map(arc_spec(), &[knot, &1])
    ])
  end

  # An ellipse (or an arc of one) somewhere in -100..100, with radii 0..50.
  @spec ellipse() :: StreamData.t(Curves.Spline.Curve.t())
  defp ellipse do
    StreamData.map(
      StreamData.tuple({
        point(),
        StreamData.float(min: 0.0, max: 50.0),
        StreamData.float(min: 0.0, max: 50.0),
        StreamData.float(min: -360.0, max: 360.0),
        StreamData.float(min: -720.0, max: 720.0),
        StreamData.float(min: -720.0, max: 720.0)
      }),
      fn {center, rx, ry, rotation, from, to} ->
        Curves.define_ellipse(center, {rx, ry}, rotation: rotation, from: from, to: to)
      end
    )
  end

  # A dial for the tension, continuity or bias of a spline, -1..1.
  @spec dial() :: StreamData.t(float())
  defp dial, do: StreamData.float(min: -1.0, max: 1.0)

  @spec cardinal(StreamData.t(list({float(), float()}))) :: StreamData.t(Curves.Spline.Curve.t())
  defp cardinal(knots) do
    StreamData.bind(knots, fn knots ->
      StreamData.map(dial(), &Curves.define_cardinal(knots, tension: &1))
    end)
  end

  @spec centripetal(StreamData.t(list({float(), float()}))) ::
          StreamData.t(Curves.Spline.Curve.t())
  defp centripetal(knots) do
    StreamData.bind(knots, fn knots ->
      StreamData.map(
        StreamData.float(min: 0.0, max: 1.0),
        &Curves.define_centripetal_catmull_rom(knots, alpha: &1)
      )
    end)
  end

  @spec kochanek_bartels(StreamData.t(list({float(), float()}))) ::
          StreamData.t(Curves.Spline.Curve.t())
  defp kochanek_bartels(knots) do
    StreamData.bind(knots, fn knots ->
      StreamData.map(StreamData.tuple({dial(), dial(), dial()}), fn {t, c, b} ->
        Curves.define_kochanek_bartels(knots, tension: t, continuity: c, bias: b)
      end)
    end)
  end

  # Data points for a monotone spline: x always increasing, by 0.01 to 20 each time.
  @spec data_points(pos_integer(), pos_integer()) :: StreamData.t(list({float(), float()}))
  defp data_points(min, max) do
    steps =
      StreamData.list_of(
        StreamData.tuple({StreamData.float(min: 0.01, max: 20.0), coord()}),
        min_length: min,
        max_length: max
      )

    StreamData.bind(coord(), fn start -> StreamData.map(steps, &add_up_x(&1, start)) end)
  end

  # Turns {gap, y} steps into points, each x `gap` past the one before, starting from `start`.
  @spec add_up_x(list({float(), float()}), float()) :: list({float(), float()})
  defp add_up_x(steps, start) do
    steps
    |> Enum.map_reduce(start, fn {gap, y}, x -> {{x + gap, y}, x + gap} end)
    |> elem(0)
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

  property "reverse travels the same path the other way" do
    check all(curve <- curve(), f <- fraction()) do
      max_u = Curves.max_u(curve)
      u = f * max_u
      reversed = Transform.reverse(curve)
      assert_near(Curves.solve!(reversed, u), Curves.solve!(curve, max_u - u), 1.0e-9)
      assert_near(Curves.solve!(Transform.reverse(reversed), u), Curves.solve!(curve, u), 1.0e-9)
    end
  end

  # The first point of a bezier or polyline is where u = 0 lands, so it's easy to watch.
  property "scaling, flipping or rotating around a point leaves that point where it was" do
    check all(
            points <- points(2, 4),
            kind <- StreamData.member_of([:bezier, :polyline]),
            position <- point(),
            {kx, ky} <-
              StreamData.tuple(
                {StreamData.float(min: -3.0, max: 3.0), StreamData.float(min: -3.0, max: 3.0)}
              ),
            deg <- StreamData.float(min: -360.0, max: 360.0),
            change <-
              StreamData.member_of([
                :set_scale,
                :inc_scale,
                :set_rotation,
                :inc_rotation,
                :flip_x,
                :flip_y
              ])
          ) do
      curve =
        case kind do
          :bezier -> Curves.define_bezier(points)
          :polyline -> Curves.define_polyline(points)
        end
        |> Transform.set_position(position)
        |> Transform.set_scale({kx, ky})
        |> Transform.set_rotation(deg)

      before = Curves.solve!(curve, 0.0)
      around = [around: hd(points)]

      changed =
        case change do
          :set_scale -> Transform.set_scale(curve, {ky, kx}, around)
          :inc_scale -> Transform.inc_scale(curve, 0.5, around)
          :set_rotation -> Transform.set_rotation(curve, deg / 2, around)
          :inc_rotation -> Transform.inc_rotation(curve, 33, around)
          :flip_x -> Transform.flip_x(curve, around)
          :flip_y -> Transform.flip_y(curve, around)
        end

      assert_near(Curves.solve!(changed, 0.0), before, 1.0e-6)
    end
  end

  property "separate x and y scales, and flips, scale each direction on its own" do
    check all(
            curve <- curve(),
            kx <- StreamData.float(min: -3.0, max: 3.0),
            ky <- StreamData.float(min: -3.0, max: 3.0),
            f <- fraction()
          ) do
      u = f * Curves.max_u(curve)
      {x, y} = Curves.solve!(curve, u)

      assert_near(
        Curves.solve!(Transform.set_scale(curve, {kx, ky}), u),
        {x * kx, y * ky},
        1.0e-6
      )

      assert_near(Curves.solve!(Transform.flip_x(curve), u), {-x, y}, 1.0e-9)
      assert_near(Curves.solve!(Transform.flip_y(curve), u), {x, -y}, 1.0e-9)

      assert_near(
        Curves.solve!(curve |> Transform.flip_x() |> Transform.flip_x(), u),
        {x, y},
        1.0e-9
      )
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

  # Beziers, B-splines, bezier splines (arcs too: they store hull points) and Hermite splines stay
  # inside their own (stored) points, and a monotone spline never overshoots its knots, so
  # force_percent stays in 0..1. Catmull-Rom
  # and the other splines through their knots can bend outside them, so they're left out.
  property "force_percent stays within 0..1 for curves that stay inside their points" do
    check all(
            curve <-
              StreamData.one_of([
                bezier(),
                StreamData.map(points(4, 8), &Curves.define_b_spline/1),
                StreamData.map(points(4, 8), &bezier_spline/1),
                StreamData.map(points(4, 8), &hermite/1),
                StreamData.map(data_points(4, 8), &Curves.define_monotone/1),
                arc_path(2, 6),
                ellipse()
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

  # The splines that are built from knots alone, and pass through every one of them.
  @spec through_knots(list({float(), float()})) :: StreamData.t(Curves.Spline.Curve.t())
  defp through_knots(knots) do
    StreamData.member_of([
      Curves.define_catmull_rom(knots),
      Curves.define_cardinal(knots, tension: 0.3),
      Curves.define_centripetal_catmull_rom(knots),
      Curves.define_kochanek_bartels(knots, tension: 0.2, continuity: -0.4, bias: 0.6),
      Curves.define_natural_cubic(knots)
    ])
  end

  @spec assert_close({float(), float()}, {float(), float()}) :: true
  defp assert_close({ax, ay} = a, {bx, by} = b) do
    scale = Enum.max([1.0, abs(ax), abs(ay), abs(bx), abs(by)])
    assert_near(a, b, 1.0e-9 * scale)
  end

  property "splines built from knots pass through every knot, at u = 0, 1, 2, ..." do
    check all(knots <- points(2, 8), curve <- through_knots(knots)) do
      knots
      |> Enum.with_index()
      |> Enum.each(fn {knot, i} -> assert_close(Curves.solve!(curve, i * 1.0), knot) end)
    end

    check all(knots <- data_points(2, 8)) do
      curve = Curves.define_monotone(knots)

      knots
      |> Enum.with_index()
      |> Enum.each(fn {knot, i} -> assert_close(Curves.solve!(curve, i * 1.0), knot) end)
    end
  end

  property "cardinal, Kochanek-Bartels and centripetal splines at their plainest are Catmull-Rom" do
    check all(knots <- points(2, 8), f <- fraction()) do
      catmull_rom = Curves.define_catmull_rom(knots)
      u = f * Curves.max_u(catmull_rom)
      expected = Curves.solve!(catmull_rom, u)

      assert_close(Curves.solve!(Curves.define_cardinal(knots), u), expected)
      assert_close(Curves.solve!(Curves.define_kochanek_bartels(knots), u), expected)

      assert_close(
        Curves.solve!(Curves.define_centripetal_catmull_rom(knots, alpha: 0.0), u),
        expected
      )
    end
  end

  property "a Kochanek-Bartels spline with only tension is a cardinal spline" do
    check all(knots <- points(2, 8), tension <- dial(), f <- fraction()) do
      cardinal = Curves.define_cardinal(knots, tension: tension)
      u = f * Curves.max_u(cardinal)

      assert_close(
        Curves.solve!(Curves.define_kochanek_bartels(knots, tension: tension), u),
        Curves.solve!(cardinal, u)
      )
    end
  end

  property "a Kochanek-Bartels spline with continuity -1 is a polyline" do
    check all(knots <- points(2, 8), f <- fraction()) do
      polyline = Curves.define_polyline(knots)
      u = f * Curves.max_u(polyline)

      assert_close(
        Curves.solve!(Curves.define_kochanek_bartels(knots, continuity: -1), u),
        Curves.solve!(polyline, u)
      )
    end
  end

  property "a monotone spline never overshoots its data, and x moves at a steady speed" do
    check all(knots <- data_points(2, 8), f <- fraction(), reversed? <- StreamData.boolean()) do
      # Decreasing x works too.
      knots = if reversed?, do: Enum.reverse(knots), else: knots
      curve = Curves.define_monotone(knots)

      knots
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.each(fn {[{x0, y0}, {x1, y1}], i} ->
        {x, y} = Curves.solve!(curve, i + f)
        assert abs(x - (x0 + f * (x1 - x0))) <= 1.0e-9 * max(1.0, abs(x))
        tolerance = 1.0e-9 * max(1.0, abs(y))
        assert y >= min(y0, y1) - tolerance and y <= max(y0, y1) + tolerance
      end)
    end
  end

  # The bend of a cubic Bezier segment [p0, p1, p2, p3] at its start and end (its second derivative).
  @spec bend_at_start(list({float(), float()})) :: {float(), float()}
  defp bend_at_start([p0, p1, p2, _p3]), do: second_difference(p0, p1, p2)

  @spec bend_at_end(list({float(), float()})) :: {float(), float()}
  defp bend_at_end([_p0, p1, p2, p3]), do: second_difference(p1, p2, p3)

  @spec second_difference({float(), float()}, {float(), float()}, {float(), float()}) ::
          {float(), float()}
  defp second_difference({ax, ay}, {bx, by}, {cx, cy}),
    do: {6 * (ax - 2 * bx + cx), 6 * (ay - 2 * by + cy)}

  property "a natural cubic spline bends smoothly at every knot, and not at all at its ends" do
    check all(knots <- points(2, 8)) do
      # The segments field is internal; this test checks the maths behind it.
      segments = Curves.define_natural_cubic(knots).segments
      tolerance = 1.0e-9 * 1000

      assert_near(bend_at_start(hd(segments)), {0.0, 0.0}, tolerance)
      assert_near(bend_at_end(List.last(segments)), {0.0, 0.0}, tolerance)

      segments
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [left, right] ->
        assert_near(bend_at_end(left), bend_at_start(right), tolerance)
      end)
    end
  end

  # Knots picked from a few places, so several often land on the same spot.
  property "splines built from knots handle knots in the same place" do
    check all(
            knots <-
              StreamData.list_of(StreamData.member_of([{0, 0}, {3, 1}, {1, 4}]),
                min_length: 1,
                max_length: 8
              ),
            alpha <- StreamData.float(min: 0.0, max: 1.0),
            f <- fraction()
          ) do
      for curve <- [
            Curves.define_centripetal_catmull_rom(knots, alpha: alpha),
            Curves.define_cardinal(knots, tension: 0.5),
            Curves.define_kochanek_bartels(knots, bias: 0.5),
            Curves.define_natural_cubic(knots)
          ] do
        {x, y} = Curves.solve!(curve, f * Curves.max_u(curve))
        assert is_float(x) and is_float(y)

        knots
        |> Enum.with_index()
        |> Enum.each(fn {{kx, ky}, i} ->
          assert_close(Curves.solve!(curve, i * 1.0), {kx * 1.0, ky * 1.0})
        end)
      end
    end
  end

  # Arcs end exactly on their knots. Lines and cubics (and arcs that SVG draws as lines, like a
  # radius of 0) land within rounding, as they always have.
  property "a path with arcs passes through every knot" do
    check all(knots <- points(2, 8), specs <- StreamData.list_of(arc_spec(), length: 7)) do
      {curves, [last]} = Enum.split(knots, -1)
      path = Enum.zip_with(curves, specs, fn knot, spec -> [knot, spec] end) ++ [[last]]
      curve = Curves.define_bezier_spline(path)

      knots
      |> Enum.with_index()
      |> Enum.each(fn {knot, i} -> assert_close(Curves.solve!(curve, i * 1.0), knot) end)

      # The segments field is internal; this checks every real arc ends exactly on its knot. (A
      # whole number u solves the end of the segment before it, so only u = 0 solves a start.)
      curve.segments
      |> Enum.with_index()
      |> Enum.each(fn
        {{:arc, _c, _a, _b, _from, _to, _start, _finish}, i} ->
          assert Curves.solve!(curve, i + 1.0) == Enum.at(knots, i + 1)

        _line ->
          :ok
      end)

      assert_first_arc_starts_exactly(curve, hd(knots))
    end
  end

  @spec assert_first_arc_starts_exactly(Curves.Spline.Curve.t(), {float(), float()}) :: :ok | true
  defp assert_first_arc_starts_exactly(
         %{segments: [{:arc, _, _, _, _, _, _, _} | _]} = curve,
         knot
       ),
       do: assert(Curves.solve!(curve, 0.0) == knot)

  defp assert_first_arc_starts_exactly(_curve, _knot), do: :ok

  property "an SVG arc of a circle stays the same distance from its centre, turning the way sweep says" do
    check all(
            p1 <- point(),
            p2 <- point(),
            r <- StreamData.float(min: 0.1, max: 200.0),
            large_arc <- StreamData.boolean(),
            sweep <- StreamData.boolean(),
            f <- fraction()
          ) do
      case Curves.Utils.Arc.from_svg(p1, {r, r, 0, large_arc, sweep}, p2) do
        {:arc, {cx, cy} = c, a, _b, from, to, _start, _finish} = arc ->
          radius =
            :math.sqrt(
              elem(Curves.Utils.Vec.subtract(a, c), 0) ** 2 +
                elem(Curves.Utils.Vec.subtract(a, c), 1) ** 2
            )

          {x, y} = arc |> Curves.Utils.Arc.prepare() |> Curves.Utils.Arc.eval(f)

          assert abs(:math.sqrt((x - cx) ** 2 + (y - cy) ** 2) - radius) <=
                   1.0e-9 * max(1.0, radius)

          assert sweep == to > from
          # A large arc turns at least half way round, a small one at most.
          half = :math.pi()

          if large_arc,
            do: assert(abs(to - from) >= half - 1.0e-9),
            else: assert(abs(to - from) <= half + 1.0e-9)

        line ->
          # Only the same start and end gives no arc here (the radius is never 0).
          assert p1 == p2 and line == [p1, p1, p1, p1]
      end
    end
  end
end
