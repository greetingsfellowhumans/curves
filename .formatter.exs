# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,bench}/**/*.{ex,exs}"],
  # Hand-aligned curve tables with end-of-line comments; the formatter would flatten them.
  excludes: ["lib/curves/bezier/predefined.ex"]
]
