# Times a single `Curves.solve!/3` on every kind of curve, with force_percent off and on.
Code.require_file("support/bench_helper.exs", __DIR__)
alias Curves.Bench.Helper

jobs =
  for {name, curve} <- Helper.curves(),
      force <- [false, true],
      into: %{} do
    # Solve at the middle of the curve. For splines that is half of max_u.
    t = Map.get(curve, :max_u, 1.0) / 2
    {"#{name} (force_percent: #{force})", fn -> Curves.solve!(curve, t, force_percent: force) end}
  end

Helper.run("solve", jobs)
