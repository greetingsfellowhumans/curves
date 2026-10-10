# Times building each kind of curve. This includes `compress`, which transforms also re-run.
Code.require_file("support/bench_helper.exs", __DIR__)
alias Curves.Bench.Helper

points = Helper.spline_points()
bezier_spline_points = Helper.bezier_spline_points()
cubic = [{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}]

Helper.run("define", %{
  "bezier cubic" => fn -> Curves.define_bezier(cubic) end,
  "spline hermite" => fn -> Curves.define_hermite(points) end,
  "spline catmull_rom" => fn -> Curves.define_catmull_rom(points) end,
  "spline b_spline" => fn -> Curves.define_b_spline(points) end,
  "spline bezier_spline" => fn -> Curves.define_bezier_spline(bezier_spline_points) end
})
