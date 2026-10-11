defmodule Curves.Bench.Helper do
  @moduledoc false
  # Shared setup for the scripts in bench/.
  # Run them with `mix bench`, or one at a time with `mix run bench/solve.exs`.

  # Short runs, so the whole suite finishes in a few minutes.
  @config [
    warmup: 1,
    time: 3,
    memory_time: 1
  ]

  # One curve of every kind, built once so the benchmarks only time solving.
  @spec curves() :: %{String.t() => Curves.Bezier.Curve.t() | Curves.Spline.Curve.t()}
  def curves() do
    %{
      "bezier linear" => Curves.define_bezier([{0.0, 0.0}, {1.0, 1.0}]),
      "bezier quadratic" => Curves.define_bezier([{0.0, 0.0}, {0.5, 1.0}, {1.0, 0.0}]),
      "bezier cubic" => Curves.define_bezier([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}]),
      "spline hermite" => Curves.define_hermite(hermite_points()),
      "spline catmull_rom" => Curves.define_catmull_rom(spline_points()),
      "spline b_spline" => Curves.define_b_spline(spline_points()),
      "spline bezier_spline" => Curves.define_bezier_spline(bezier_spline_points())
    }
  end

  # The same six knots with a tangent each, for define_hermite/2.
  @spec hermite_points() :: list([Curves.Types.point_tuple()])
  def hermite_points(), do: Enum.map(spline_points(), fn {x, y} -> [{x, y}, {5.0, y - 10.0}] end)

  # Six knots, giving a spline with several segments.
  @spec spline_points() :: Curves.Types.point_list()
  def spline_points() do
    [
      {5.0, 10.0},
      {10.0, 5.0},
      {15.0, 10.0},
      {20.0, 10.0},
      {25.0, 5.0},
      {30.0, 15.0}
    ]
  end

  # Knots with control points, in the format `define_bezier_spline/2` expects: each knot, then the
  # control points of the curve to the next knot. The last knot only ends the curve.
  @spec bezier_spline_points() :: list(Curves.Types.point_list())
  def bezier_spline_points() do
    [
      [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],
      [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}],
      [{15.0, 10.0}, {15.0, 14.0}, {18.0, 15.0}],
      [{20.0, 15.0}, {23.0, 15.0}, {32.0, 5.0}],
      [{30.0, 10.0}]
    ]
  end

  # Runs Benchee with the shared config.
  #
  # `name` picks the results files, e.g. "solve" uses bench/results/solve-<tag>.benchee.
  # With a tag (`mix run bench/solve.exs baseline`), this run is only saved under it.
  # Without one, every saved run for `name` is loaded and this run is compared against them.
  @spec run(String.t(), map(), keyword()) :: Benchee.Suite.t()
  def run(name, jobs, opts \\ []) do
    config =
      @config
      |> Keyword.merge(opts)
      |> Keyword.merge(results_opts(name, System.argv()))

    Benchee.run(jobs, config)
  end

  # Saving and comparing are kept apart: Benchee saves loaded runs too,
  # so saving while comparing would copy old runs into every new file.
  @spec results_opts(String.t(), list(String.t())) :: keyword()
  defp results_opts(name, []), do: [load: "bench/results/#{name}-*.benchee"]

  defp results_opts(name, [tag | _]),
    do: [save: [path: "bench/results/#{name}-#{tag}.benchee", tag: tag]]
end
