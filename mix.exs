defmodule Curves.MixProject do
  use Mix.Project

  def project do
    [
      app: :curves,
      version: "0.1.0",
      elixir: "~> 1.10",
      description: description(),
      cli: cli(),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/greetingsfellowhumans/curves",
      package: package(),
      deps: deps()
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
      {:nx, "~> 0.13"},

      #{:exla, "~> 0.9", only: [:dev, :test]},
      #{:benchee, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:tucan, "~> 0.6.0", only: [:dev, :test], runtime: false},
      {:vega_lite, "~> 0.1.0", only: [:dev, :test], runtime: false},
      {:kino_vega_lite, "~> 0.1.0", only: :dev, runtime: false},
      #{:vega_lite_convert, "~> 1.0.1", only: [:dev, :test]},
      {:mix_test_interactive, "~> 5.1", only: [:dev, :test], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
