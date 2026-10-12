# Draws every image used by the guides (guides/images/*.svg) and the README (assets/examples/*.svg)
# with Curves.Svg, so the pictures always match the code. `mix docs` runs it first (see the alias
# in mix.exs); run it on its own with:
#
#     mix run guides/images/generate.exs
#
# Each entry is {file, curve (or Curves.Drawing), Svg options}. The code shown next to an image in the guides should
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

# Two knots bunched up between two far away: plain Catmull-Rom loops here, centripetal doesn't.
bunched = [{0, 0}, {10, 10}, {10.5, 10}, {20, 0}]
# SVG: M 0 0 L 10 0 A 5 5 0 0 1 10 10 L 0 10
arc_path =
  Curves.define_bezier_spline([
    [{0, 0}],
    [{10, 0}, {:arc, 5, 5, 0, false, true}],
    [{10, 10}],
    [{0, 10}]
  ])

# A little SVG for the "reading SVGs" pictures: a house with a round window, a door and a chimney.
# The tutorial shows the same SVG.
house_svg = """
<svg width="300" height="300" viewBox="0 0 100 100">
  <rect x="0" y="0" width="100" height="100" fill="#e7f5ff"/>
  <polygon points="10,50 50,15 90,50" fill="#e03131"/>
  <rect x="18" y="50" width="64" height="40" fill="#ffe8cc" stroke="#862e9c"/>
  <rect x="42" y="65" width="16" height="25" rx="3" fill="#862e9c"/>
  <circle cx="50" cy="35" r="6" fill="#fff" stroke="#862e9c" stroke-width="2"/>
  <path d="M 70 30 V 18 h 8 v 22" fill="#495057"/>
  <text x="50" y="98" font-size="6" text-anchor="middle">Home</text>
</svg>
"""

# Chart data with flat stretches, where most splines overshoot and a monotone one doesn't.
data = [{0, 2}, {1, 2}, {2, 2}, {3, 8}, {4, 8.5}, {5, 3}, {6, 3}]

shape = Curves.define_bezier([{0, 0}, {1, 3}, {3, 3}, {4, 0}])
# One fixed area for the three rotation pictures, so you can compare where the shape ends up.
pivot_view = {{-4, -1}, {5, 5}}

# Every predefined curve. The tutorial shows some of them and the Curves.Bezier.Predefined
# moduledoc shows them all.
predefined_gallery =
  for key <- Curves.Bezier.Predefined.list() do
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
    {"#{guides}/spline_cardinal.svg", Curves.define_cardinal(knots, tension: 0.5),
     small ++ [title: "Cardinal: tension 0.5", markers: knots]},
    {"#{guides}/spline_kochanek_bartels.svg", Curves.define_kochanek_bartels(knots, bias: 0.5),
     small ++ [title: "Kochanek-Bartels: bias 0.5", markers: knots]},
    {"#{guides}/spline_bunched_catmull_rom.svg", Curves.define_catmull_rom(bunched),
     medium ++ [title: "Catmull-Rom: a little loop", markers: bunched]},
    {"#{guides}/spline_centripetal.svg", Curves.define_centripetal_catmull_rom(bunched),
     medium ++ [title: "Centripetal: no loop", markers: bunched]},
    {"#{guides}/spline_data_catmull_rom.svg", Curves.define_catmull_rom(data),
     small ++ [title: "Catmull-Rom: overshoots", markers: data]},
    {"#{guides}/spline_monotone.svg", Curves.define_monotone(data),
     small ++ [title: "Monotone: never overshoots", markers: data]},
    {"#{guides}/spline_natural_cubic.svg", Curves.define_natural_cubic(knots),
     small ++ [title: "Natural cubic: through every knot", markers: knots]},

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
    {"#{guides}/transform_stretched.svg", Transform.set_scale(shape, {2, 0.5}),
     small ++ [title: "set_scale(shape, {2, 0.5})"]},
    {"#{guides}/transform_flipped.svg", Transform.flip_y(shape, around: :center),
     small ++ [title: "flip_y(shape, around: :center)"]},
    {"#{guides}/transform_pivot_none.svg", shape,
     small ++ [title: "The original", view: pivot_view]},
    {"#{guides}/transform_pivot_position.svg", Transform.set_rotation(shape, 90),
     small ++ [title: "set_rotation(shape, 90)", view: pivot_view, markers: [{0, 0}]]},
    {"#{guides}/transform_pivot_center.svg", Transform.set_rotation(shape, 90, around: :center),
     small ++ [title: "...around: :center", view: pivot_view, markers: [{2, 1.5}]]},
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
    {"#{guides}/spline_arc_path.svg", arc_path,
     medium ++
       [title: "L, then A (a half circle), then L", markers: [{0, 0}, {10, 0}, {10, 10}, {0, 10}]]},
    {"#{guides}/ellipse.svg", Curves.define_ellipse({0, 0}, {4, 2}, rotation: 30),
     small ++ [title: "define_ellipse, rotation: 30"]},
    {"#{guides}/circle_arc.svg", Curves.define_circle({0, 0}, 2, from: 90, to: 180),
     small ++ [title: "define_circle, from: 90, to: 180", markers: [{0, 0}]]},
    {"#{guides}/svg_import_drawing.svg", Curves.from_svg(house_svg), []},
    {"#{guides}/svg_import_curves.svg", Curves.from_svg(house_svg, flip_y: true),
     medium ++ [title: "mode: :inspect", mode: :inspect]},
    {"#{guides}/svg_import_heart.svg",
     hd(
       Curves.from_svg_path(
         "M 10,30 A 20,20 0,0,1 50,30 A 20,20 0,0,1 90,30 Q 90,60 50,90 Q 10,60 10,30 z",
         flip_y: true
       )
     ).curve, medium ++ [title: "Curves.from_svg_path(heart, flip_y: true)"]},

    # Choosing a curve
    {"#{guides}/choose_data_natural.svg", Curves.define_natural_cubic(data),
     small ++ [title: "Natural cubic: overshoots too", markers: data]},
    {"#{guides}/choose_data_polyline.svg", Curves.define_polyline(data),
     small ++ [title: "Polyline: exact, but sharp", markers: data]}
  ] ++
    for(
      large_arc <- [false, true],
      sweep <- [false, true],
      do:
        {"#{guides}/arc_flags_#{large_arc}_#{sweep}.svg",
         Curves.define_bezier_spline([[{0, 0}, {:arc, 10, 10, 0, large_arc, sweep}], [{10, 0}]]),
         small ++
           [
             title: "large_arc: #{large_arc}, sweep: #{sweep}",
             markers: [{0, 0}, {10, 0}],
             view: {{-12, -22}, {22, 22}}
           ]}
    ) ++
    for(
      tension <- [-0.5, 0.0, 0.5, 1.0],
      do:
        {"#{guides}/choose_tension_#{tension}.svg",
         Curves.define_cardinal(knots, tension: tension),
         small ++ [title: "tension: #{tension}", markers: knots]}
    ) ++
    for(
      {dial, value} <- [continuity: -0.7, continuity: 0.7, bias: -0.7, bias: 0.7],
      do:
        {"#{guides}/choose_#{dial}_#{value}.svg",
         Curves.define_kochanek_bartels(knots, [{dial, value}]),
         small ++ [title: "#{dial}: #{value}", markers: knots]}
    ) ++
    [
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
       [width: 400, height: 400, samples: 400, title: "B-Spline"]},
      {"#{readme}/cardinal.svg",
       Curves.define_cardinal([{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}], tension: 0.5),
       [width: 400, height: 400, samples: 400, title: "Cardinal Spline (tension 0.5)"]},
      {"#{readme}/centripetal_catmull_rom.svg", Curves.define_centripetal_catmull_rom(bunched),
       [width: 400, height: 400, samples: 400, title: "Centripetal Catmull-Rom Spline"]},
      {"#{readme}/kochanek_bartels.svg",
       Curves.define_kochanek_bartels([{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}],
         tension: 0.2,
         continuity: -0.3,
         bias: 0.4
       ), [width: 400, height: 400, samples: 400, title: "Kochanek-Bartels Spline"]},
      {"#{readme}/monotone.svg", Curves.define_monotone(data),
       [width: 400, height: 400, samples: 400, title: "Monotone Spline"]},
      {"#{readme}/natural_cubic.svg",
       Curves.define_natural_cubic([{0, -2}, {3, 4}, {6, 5}, {7, -1}, {10, 3}, {5, 1}, {12, 9}]),
       [width: 400, height: 400, samples: 400, title: "Natural Cubic Spline"]},
      {"#{readme}/ellipse.svg", Curves.define_ellipse({0, 0}, {4, 2}, rotation: 30),
       [width: 400, height: 400, samples: 400, title: "Ellipse (rotation 30)"]},
      {"#{readme}/arc_path.svg", arc_path,
       [width: 400, height: 400, samples: 400, title: "Bezier spline with an arc"]}
    ] ++ predefined_gallery

File.mkdir_p!(guides)

for {path, curve, opts} <- images, do: Curves.Svg.save!(curve, path, opts)

IO.puts("Drew #{length(images)} images into #{guides} and #{readme}")
