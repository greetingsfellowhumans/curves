defmodule Curves.MixProject do
  use Mix.Project

  def project do
    [
      app: :curves,
      version: "0.2.1",
      elixir: "~> 1.17",
      description: description(),
      cli: cli(),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/greetingsfellowhumans/curves",
      package: package(),
      deps: deps(),
      docs: docs(),
    ]
  end

  defp docs() do
    [
      main: "Curves",
      extras: [
        "CHANGELOG.md",
        "guides/bezier_curves.livemd"
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
    ]
  end

  defp description(),
    do: "High performance splines and bezier curves in a simple, user-friendly interface."

  defp package() do
    [
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["greetingsfellowhumans"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/greetingsfellowhumans/curves"}
    ]
  end

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
      # Required
      {:nx, "~> 0.8"},

      # dev/test only.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_test_interactive, "~> 5.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
    ]
  end
end
