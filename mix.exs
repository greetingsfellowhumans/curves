defmodule Curves.MixProject do
  use Mix.Project

  def project do
    [
      app: :curves,
      version: "1.0.0-rc.2",
      elixir: "~> 1.17",
      description: description(),
      elixirc_paths: elixirc_paths(Mix.env()),
      cli: cli(),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/greetingsfellowhumans/curves",
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs()
    ]
  end

  defp docs() do
    [
      main: "introduction",
      extras: [
        "guides/introduction.md",
        "guides/tutorial/first_curve.md",
        "guides/tutorial/bezier_curves.md",
        "guides/tutorial/splines.md",
        "guides/tutorial/transforms.md",
        "guides/livebooks/01_first_curve.livemd",
        "guides/livebooks/02_bezier_curves.livemd",
        "guides/livebooks/03_splines.livemd",
        "guides/livebooks/04_transforms.livemd",
        "guides/choosing_a_curve.md",
        "guides/upgrading.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorial: ~r"guides/tutorial/",
        "Interactive tutorial (Livebook)": ~r"guides/livebooks/",
        Guides: ["guides/choosing_a_curve.md"],
        "Upgrading and changes": ["guides/upgrading.md", "CHANGELOG.md"]
      ],
      # The tutorial's pictures, drawn by guides/images/generate.exs.
      assets: %{"guides/images" => "images"},
      nest_modules_by_prefix: [
        Curves.Spline.Type,
        Curves.Drawing
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp description(),
    do: "High performance splines and bezier curves in a simple, user-friendly interface."

  defp package() do
    [
      files: ["lib", "mix.exs", "README*", "CHANGELOG*", "LICENSE*"],
      maintainers: ["greetingsfellowhumans"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/greetingsfellowhumans/curves"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp cli() do
    [preferred_cli_env: ["test.watch": :test]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # No runtime dependencies. Everything below is for development and tests only.
      {:stream_data, "~> 1.0", only: [:test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_test_interactive, "~> 5.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end

  defp aliases() do
    [
      bench: &bench/1,
      # Redraw the guides' pictures first, so they always match the code.
      docs: ["run guides/images/generate.exs", "docs"]
    ]
  end

  # Runs every benchmark script. Any args (e.g. a tag to save the run under) are passed through.
  # `mix run` only runs once per invocation, so it has to be re-enabled for each script.
  @spec bench(list(String.t())) :: :ok
  defp bench(args) do
    Enum.each(
      ["bench/solve.exs", "bench/take.exs", "bench/define.exs", "bench/svg_import.exs"],
      fn script ->
        Mix.Task.rerun("run", [script | args])
      end
    )
  end
end
