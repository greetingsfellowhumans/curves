# Times `Curves.take!/3` at a few sample counts, to show how it scales with n.
Code.require_file("support/bench_helper.exs", __DIR__)
alias Curves.Bench.Helper

curves = Helper.curves()
bezier = curves["bezier cubic"]
spline = curves["spline catmull_rom"]

Helper.run(
  "take",
  %{
    "bezier cubic" => fn n -> Curves.take!(bezier, n) end,
    "spline catmull_rom" => fn n -> Curves.take!(spline, n) end
  },
  inputs: [{"n = 10", 10}, {"n = 100", 100}, {"n = 1_000", 1_000}]
)
