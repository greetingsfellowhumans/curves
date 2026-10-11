defmodule Curves.Support.ReferenceResults do
  @moduledoc false
  # Known-good results to compare the library against. `write!/0` records what the current code
  # returns into test/fixtures/reference_results.etf; reference_results_test.exs checks the
  # code still returns the same thing, within a small tolerance.
  #
  # Only regenerate when a change in results is intended. See test/fixtures/README.md.

  alias Curves.Transform

  @path Path.join([__DIR__, "..", "fixtures", "reference_results.etf"])

  @cubic [{0, 0}, {1, 3}, {2, -1}, {3, 1}]
  @six [{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}]
  @hermite [{5, 10}, {10, 5}, {15, 10}, {20, 10}, {25, 5}, {30, 15}]
  @b_spline [{0, -2}, {3, 4}, {6, 5}, {7, -1}, {10, 3}, {5, 1}, {12, 9}]
  @bezier_spline [
    [{5.0, 10.0}, {10.0, 10.0}],
    [{10.0, 5.0}, {5.0, 5.0}, {15.0, 5.0}],
    [{15.0, 10.0}, {15.0, 6.0}, {15.0, 14.0}],
    [{20.0, 15.0}, {18.0, 15.0}, {23.0, 15.0}],
    [{30.0, 10.0}, {32.0, 5.0}]
  ]

  # Transforms applied on top of a defined curve. `{:origin, xy}` is a define option instead.
  @transforms [
    none: [],
    origin: [{:origin, {2, 3}}],
    moved: [{:set_position, [{5, -2}]}],
    inc_x: [{:inc_x, [1.5]}],
    scaled: [{:set_scale, [2.0]}],
    negative_scale: [{:set_scale, [-1.5]}],
    rotated_90: [{:set_rotation, [90]}],
    rotated_37: [{:inc_rotation, [37.0]}],
    combined: [
      {:origin, {2, 3}},
      {:set_position, [{1, 1}]},
      {:set_scale, [0.5]},
      {:set_rotation, [30]}
    ]
  ]

  # Every case: {name, function from extra define opts to a curve}.
  @spec cases() :: list({String.t(), (keyword() -> Curves.Types.curve_struct())})
  def cases do
    predefined =
      for key <- Curves.Bezier.Predefined.list(),
          do: {"predefined #{key}", fn opts -> Curves.define_bezier(key, opts) end}

    custom = [
      {"bezier 2 points", fn opts -> Curves.define_bezier([{0, 0}, {3, 4}], opts) end},
      {"bezier 3 points", fn opts -> Curves.define_bezier([{0, 0}, {1, 2}, {2, 0}], opts) end},
      {"bezier 4 points", fn opts -> Curves.define_bezier(@cubic, opts) end},
      {"catmull_rom 6 points", fn opts -> Curves.define_catmull_rom(@six, opts) end},
      {"catmull_rom 4 points",
       fn opts -> Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}], opts) end},
      {"hermite 6 points", fn opts -> Curves.define_hermite(@hermite, opts) end},
      {"hermite 3 points", fn opts -> Curves.define_hermite([{0, 0}, {1, 1}, {2, 0}], opts) end},
      {"b_spline 6 points", fn opts -> Curves.define_b_spline(@six, opts) end},
      {"b_spline 7 points", fn opts -> Curves.define_b_spline(@b_spline, opts) end},
      {"bezier_spline 5 points",
       fn opts -> Curves.define_bezier_spline(@bezier_spline, opts) end},
      {"bezier_spline 2 points",
       fn opts -> Curves.define_bezier_spline([[{0, 0}, {1, 2}], [{3, 0}, {2, 2}]], opts) end}
    ]

    transformed =
      for {name, build} <- custom, {t_name, steps} <- @transforms, t_name != :none do
        {"#{name} #{t_name}", fn opts -> apply_steps(build, steps, opts) end}
      end

    predefined ++ custom ++ transformed
  end

  # The tolerance (relative, or absolute near zero) every recorded number must match within.
  # The recording code was Nx-based: even with `float_dtype: 64`, it built `t`, its powers and the
  # rotation angle as 32-bit floats, so recorded values carry rounding of about 1e-7. A real bug
  # (a wrong matrix, a transform in the wrong order) is off by far more than 1e-6.
  @spec tolerance(String.t()) :: float()
  def tolerance(_name), do: 1.0e-6

  # Builds the curve, applying define options first and then each transform in order.
  @spec apply_steps((keyword() -> struct()), keyword() | list(), keyword()) :: struct()
  defp apply_steps(build, steps, opts) do
    define_opts = for {:origin, xy} <- steps, do: {:origin, xy}
    curve = build.(Keyword.merge(opts, define_opts))

    Enum.reduce(steps, curve, fn
      {:origin, _}, curve -> curve
      {fun, args}, curve -> apply(Transform, fun, [curve | args])
    end)
  end

  # Everything recorded for one curve.
  @spec record(Curves.Types.curve_struct()) :: map()
  def record(curve) do
    max_u = Curves.max_u(curve)
    boundaries = for i <- 0..trunc(max_u), do: i * 1.0

    us =
      Enum.uniq(
        [0.0, 1.0e-5, -0.0005, 0.1, 0.25, 0.5, max_u / 2, max_u - 0.001, max_u] ++ boundaries
      )

    %{
      solve: for(u <- us, do: {u, Curves.solve(curve, u)}),
      solve_percent: for(u <- us, do: {u, Curves.solve(curve, u, force_percent: true)}),
      take: Curves.take(curve, 9),
      take_percent: Curves.take(curve, 9, force_percent: true),
      svg: Curves.Svg.render(curve, samples: 20, width: 200, height: 200)
    }
  end

  # Records every case with 64-bit floats and writes the fixture file.
  @spec write!() :: :ok
  def write! do
    results = Map.new(cases(), fn {name, build} -> {name, record(build.(float_dtype: 64))} end)
    File.mkdir_p!(Path.dirname(@path))
    File.write!(@path, :erlang.term_to_binary(results))
    IO.puts("Wrote #{map_size(results)} cases to #{Path.relative_to_cwd(@path)}")
  end

  # The recorded results, keyed by case name.
  @spec read!() :: map()
  def read!, do: @path |> File.read!() |> :erlang.binary_to_term()
end
