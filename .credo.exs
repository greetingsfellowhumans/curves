# Credo's defaults, minus the checks this project deliberately doesn't follow.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "bench/", "config/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: %{
        disabled: [
          # Fully qualified calls like Curves.Utils.Opts.merge_opts/1 are fine; aliasing them is optional.
          {Credo.Check.Design.AliasUsage, []},
          # Zero-arity functions are written with parentheses, e.g. `def point_count(), do: 4`.
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          # apply/3 is used on purpose in tests to pass deliberately bad input past the type checker.
          {Credo.Check.Refactor.Apply, []}
        ]
      }
    }
  ]
}
