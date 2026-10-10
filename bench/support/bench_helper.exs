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
      "spline hermite" => Curves.define_hermite(spline_points()),
      "spline catmull_rom" => Curves.define_catmull_rom(spline_points()),
      "spline b_spline" => Curves.define_b_spline(spline_points()),
      "spline bezier_spline" => Curves.define_bezier_spline(bezier_spline_points())
    }
  end

  # Six knots, giving a spline with several segments.
  @spec spline_points() :: Curves.Utils.Types.point_list()
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

  # Knots with control points, in the format `define_bezier_spline/2` expects.
  @spec bezier_spline_points() :: list(Curves.Utils.Types.point_list())
  def bezier_spline_points() do
    [
      [{5.0, 10.0}, {10.0, 10.0}],
      [{10.0, 5.0}, {5.0, 5.0}, {15.0, 5.0}],
      [{15.0, 10.0}, {15.0, 6.0}, {15.0, 14.0}],
      [{20.0, 15.0}, {18.0, 15.0}, {23.0, 15.0}],
      [{30.0, 10.0}, {32.0, 5.0}]
    ]
  end

  # Runs Benchee with the shared config.
  #
  # `name` picks the results files, e.g. "solve" uses bench/results/solve-<tag>.benchee.
  # Every saved run for `name` is loaded, so this run is compared against them.
  # If a tag was passed (`mix run bench/solve.exs -- baseline`), this run is saved under it.
  @spec run(String.t(), map(), keyword()) :: Benchee.Suite.t()
  def run(name, jobs, opts \\ []) do
    IO.puts("Nx backend: #{inspect(Nx.default_backend())}\n")

    config =
      @config
      |> Keyword.merge(opts)
      |> Keyword.merge(load: "bench/results/#{name}-*.benchee")
      |> Keyword.merge(save_opts(name, System.argv()))

    Benchee.run(jobs, config)
  end

  # No tag means nothing is saved.
  @spec save_opts(String.t(), list(String.t())) :: keyword()
  defp save_opts(_name, []), do: []

  defp save_opts(name, [tag | _]),
    do: [save: [path: "bench/results/#{name}-#{tag}.benchee", tag: tag]]
end
