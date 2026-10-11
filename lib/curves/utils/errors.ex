defmodule Curves.Utils.Errors do
  @moduledoc false
  # Errors shared by several modules, so their messages stay the same everywhere.

  # Raised when a function that takes a curve gets something else, e.g. `Curves.solve(:nope, 0.5)`.
  # It is the last branch of each `cond` that picks between Bezier and Spline.
  @spec raise_not_a_curve(term()) :: no_return()
  def raise_not_a_curve(term) do
    raise ArgumentError,
          "expected a Curves.Bezier.Curve or Curves.Spline.Curve, got: #{inspect(term)}"
  end
end
