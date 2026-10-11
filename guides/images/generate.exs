# Draws every image used by the guides (guides/images/*.svg) and the README (assets/examples/*.svg)
# with Curves.Svg, so the pictures always match the code. `mix docs` runs it first (see the alias
# in mix.exs); run it on its own with:
#
#     mix run guides/images/generate.exs
#
# Each entry is {file, curve, Svg options}. The code shown next to an image in the guides should
# match its entry here.

alias Curves.Transform

guides = "guides/images"
readme = "assets/examples"

# A smaller picture for galleries and side-by-side comparisons.
small = [width: 300, height: 240, padding: 32, samples: 200]
medium = [width: 480, height: 360, samples: 200]

ease_in_out = Curves.define_bezier(:ease_in_out)
knots = [{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}]

mixed_spline =
  Curves.define_bezier_spline([
    # straight line (L)
    [{0, 0}],
    # quadratic curve (Q)
    [{3, 2}, {4.5, 5}],
    # cubic curve (C)
    [{6, 2}, {7, 0}, {9, 5}],
    # the last knot only ends the curve
    [{10, 2}]
  ])

hermite = fn middle_tangent ->
  Curves.define_hermite([[{0, 0}, {4, 0}], [{4, 2}, middle_tangent], [{8, 0}, {4, 0}]])
end

shape = Curves.define_bezier([{0, 0}, {1, 3}, {3, 3}, {4, 0}])

predefined_gallery =
  for key <- [
        :linear,
        :ease,
        :ease_in,
        :ease_out,
        :ease_in_out,
        :ease_in_back,
        :ease_out_back,
        :ease_in_out_back,
        :ease_in_expo,
        :ease_out_circ,
        :ease_in_out_cubic,
        :quadratic_down
      ] do
    {"#{guides}/predefined_#{key}.svg", Curves.define_bezier(key),
     small ++ [title: inspect(key), show_axes: false]}
  end

images =
  [
    # Getting started (the landing page)
    {"#{guides}/intro_ease_in_out.svg", ease_in_out, medium ++ [title: ":ease_in_out"]},
    {"#{guides}/intro_solve.svg", ease_in_out,
     medium ++ [title: "Curves.solve!(curve, 0.5)", markers: [Curves.solve!(ease_in_out, 0.5)]]},
    {"#{guides}/intro_spline.svg", Curves.define_catmull_rom(knots),
     medium ++ [title: "A Catmull-Rom spline through 5 knots"]},

    # 1. Your first curve
    {"#{guides}/first_curve.svg", ease_in_out,
     medium ++ [title: "Curves.define_bezier(:ease_in_out)"]},
    {"#{guides}/first_curve_t.svg", ease_in_out,
     medium ++
       [
         title: "t = 0, 0.25, 0.5, 0.75 and 1",
         markers: for(t <- [0.0, 0.25, 0.5, 0.75, 1.0], do: Curves.solve!(ease_in_out, t))
       ]},
    {"#{guides}/first_curve_take.svg", ease_in_out,
     medium ++ [title: "Curves.take!(curve, 10)", markers: Curves.take!(ease_in_out, 10)]},

    # 2. Bezier curves
    {"#{guides}/bezier_linear.svg", Curves.define_bezier([{0, 0}, {4, 3}]),
     small ++ [title: "2 points: a straight line"]},
    {"#{guides}/bezier_quadratic.svg", Curves.define_bezier([{0, 0}, {2, 4}, {4, 0}]),
     small ++ [title: "3 points: quadratic"]},
    {"#{guides}/bezier_cubic.svg", Curves.define_bezier([{0, 0}, {1, 4}, {3, -1}, {4, 3}]),
     small ++ [title: "4 points: cubic"]},
    {"#{guides}/bezier_pull_gentle.svg", Curves.define_bezier([{0, 0}, {1, 1}, {3, 1}, {4, 0}]),
     small ++ [title: "Gentle pull"]},
    {"#{guides}/bezier_pull_strong.svg", Curves.define_bezier([{0, 0}, {1, 4}, {3, 4}, {4, 0}]),
     small ++ [title: "Strong pull"]},
    {"#{guides}/bezier_pull_s.svg", Curves.define_bezier([{0, 0}, {1, 4}, {3, -4}, {4, 0}]),
     small ++ [title: "Opposite pulls: an S"]},
    {"#{guides}/bezier_css.svg",
     Curves.define_bezier([{0, 0}, {0.68, -0.55}, {0.27, 1.55}, {1, 1}]),
     medium ++ [title: "cubic-bezier(0.68, -0.55, 0.27, 1.55)"]},

    # 3. Splines
    {"#{guides}/spline_u.svg", Curves.define_catmull_rom(knots),
     medium ++
       [
         title: "u = 0, 1, 2, 3 and 4 land on the knots",
         markers: for(u <- 0..4, do: Curves.solve!(Curves.define_catmull_rom(knots), u))
       ]},
    {"#{guides}/polyline.svg", Curves.define_polyline(knots),
     medium ++
       [
         title: "A polyline: u = 1.5 is halfway along the second line",
         markers: [Curves.solve!(Curves.define_polyline(knots), 1.5)]
       ]},
    {"#{guides}/spline_bezier_lqc.svg", mixed_spline, medium ++ [title: "L, then Q, then C"]},
    {"#{guides}/spline_catmull_rom.svg", Curves.define_catmull_rom(knots),
     small ++ [title: "Catmull-Rom: through every knot", markers: knots]},
    {"#{guides}/spline_b_spline.svg", Curves.define_b_spline(knots),
     small ++
       [
         title: "B-spline: smooth, near the knots",
         markers: knots,
         show_points: false,
         show_polygon: false
       ]},
    {"#{guides}/spline_hermite_short.svg", hermite.({2, 0}),
     small ++ [title: "Hermite: short tangent"]},
    {"#{guides}/spline_hermite_long.svg", hermite.({12, 0}),
     small ++ [title: "Hermite: long tangent"]},

    # 4. Transforms and drawing
    {"#{guides}/transform_original.svg", shape, small ++ [title: "The original"]},
    {"#{guides}/transform_moved.svg", Transform.set_position(shape, {5, 2}),
     small ++ [title: "set_position({5, 2})"]},
    {"#{guides}/transform_scaled.svg", Transform.set_scale(shape, 2),
     small ++ [title: "set_scale(2)"]},
    {"#{guides}/transform_rotated.svg", Transform.set_rotation(shape, 90),
     small ++ [title: "set_rotation(90)"]},
    {"#{guides}/transform_all.svg",
     shape
     |> Transform.set_position({5, 2})
     |> Transform.set_scale(2)
     |> Transform.set_rotation(45),
     medium ++
       [
         title: "Moved, scaled and rotated: the start stays at {5, 2}",
         markers: [{5, 2}]
       ]},
    {"#{guides}/transform_percent.svg", Transform.set_scale(shape, 3),
     medium ++
       [
         title: "force_percent: true",
         solve_opts: [force_percent: true],
         show_points: false,
         show_polygon: false
       ]},
    {"#{guides}/svg_styled.svg", Curves.define_catmull_rom(knots),
     medium ++
       [
         title: "Your colours",
         curve_color: "#e64980",
         curve_width: 6,
         point_color: "#5c940d",
         polygon_color: "#fab005",
         background: "#fff9db",
         show_axes: false
       ]},

    # README examples (assets/examples)
    {"#{readme}/ease_in_out.svg", ease_in_out,
     [width: 400, height: 400, samples: 400, title: "Ease in-out"]},
    {"#{readme}/quadratic.svg", Curves.define_bezier([{0, 0}, {20, 50}, {100, 0}]),
     [width: 400, height: 400, samples: 400, title: "Quadratic Bezier"]},
    {"#{readme}/custom_bezier.svg",
     Curves.define_bezier([{0, 0}, {0.8, 0.2}, {0.3, 2.2}, {1, 1}]),
     [width: 400, height: 400, samples: 400, title: "Custom 4-point Bezier"]},
    {"#{readme}/bezier_spline.svg",
     Curves.define_bezier_spline([
       [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],
       [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}],
       [{15.0, 10.0}, {15.0, 14.0}, {18.0, 15.0}],
       [{20.0, 15.0}, {23.0, 15.0}, {32.0, 5.0}],
       [{30.0, 10.0}]
     ]), [width: 400, height: 400, samples: 400, title: "Bezier Spline"]},
    {"#{readme}/polyline.svg", Curves.define_polyline([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}]),
     [width: 400, height: 400, samples: 400, title: "Polyline"]},
    {"#{readme}/hermite.svg",
     Curves.define_hermite([
       [{5, 10}, {5, -5}],
       [{10, 5}, {5, 0}],
       [{15, 10}, {5, 5}],
       [{20, 10}, {5, -3}],
       [{25, 5}, {5, 5}],
       [{30, 15}, {5, 10}]
     ]), [width: 400, height: 400, samples: 400, title: "Hermite Spline"]},
    {"#{readme}/catmull_rom.svg",
     Curves.define_catmull_rom([{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}]),
     [width: 400, height: 400, samples: 400, title: "Catmull-Rom Spline"]},
    {"#{readme}/b_spline.svg",
     Curves.define_b_spline([{0, -2}, {3, 4}, {6, 5}, {7, -1}, {10, 3}, {5, 1}, {12, 9}]),
     [width: 400, height: 400, samples: 400, title: "B-Spline"]}
  ] ++ predefined_gallery

File.mkdir_p!(guides)

for {path, curve, opts} <- images, do: Curves.Svg.save!(curve, path, opts)

IO.puts("Drew #{length(images)} images into #{guides} and #{readme}")
