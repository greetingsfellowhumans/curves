# Times building each kind of curve. This includes `compress`, which transforms also re-run.
# Then times the splines built from 1000 knots each.
Code.require_file("support/bench_helper.exs", __DIR__)
alias Curves.Bench.Helper

points = Helper.spline_points()
hermite_points = Helper.hermite_points()
bezier_spline_points = Helper.bezier_spline_points()
cubic = [{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}]

Helper.run("define", %{
  "bezier cubic" => fn -> Curves.define_bezier(cubic) end,
  "spline hermite" => fn -> Curves.define_hermite(hermite_points) end,
  "spline catmull_rom" => fn -> Curves.define_catmull_rom(points) end,
  "spline b_spline" => fn -> Curves.define_b_spline(points) end,
  "spline bezier_spline" => fn -> Curves.define_bezier_spline(bezier_spline_points) end,
  "spline cardinal" => fn -> Curves.define_cardinal(points, tension: 0.5) end,
  "spline centripetal_catmull_rom" => fn -> Curves.define_centripetal_catmull_rom(points) end,
  "spline kochanek_bartels" => fn -> Curves.define_kochanek_bartels(points, bias: 0.4) end,
  "spline monotone" => fn -> Curves.define_monotone(points) end,
  "spline natural_cubic" => fn -> Curves.define_natural_cubic(points) end
})

# The same splines from 1000 knots, to show how building them grows with the number of knots.
many = Helper.many_points(1000)

Helper.run("define_1000", %{
  "spline catmull_rom" => fn -> Curves.define_catmull_rom(many) end,
  "spline b_spline" => fn -> Curves.define_b_spline(many) end,
  "spline cardinal" => fn -> Curves.define_cardinal(many, tension: 0.5) end,
  "spline centripetal_catmull_rom" => fn -> Curves.define_centripetal_catmull_rom(many) end,
  "spline kochanek_bartels" => fn -> Curves.define_kochanek_bartels(many, bias: 0.4) end,
  "spline monotone" => fn -> Curves.define_monotone(many) end,
  "spline natural_cubic" => fn -> Curves.define_natural_cubic(many) end
})
