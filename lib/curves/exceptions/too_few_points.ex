# Public API name. Credo guesses an `Out` prefix rule from OutOfBoundT/OutOfBoundU, which does not apply here.
# credo:disable-for-next-line Credo.Check.Consistency.ExceptionNames
defmodule Curves.Exceptions.TooFewPoints do
  @moduledoc ~s"""
  Raised by `Curves.solve!/3` and `Curves.take!/3` for a bezier curve defined with fewer than 2 points.
  `Curves.solve/3` returns `{:error, {:too_few_points, n, 2}}` instead.

  Fields: `:message`, `:n` (how many points the curve has) and `:min` (the minimum, 2).
  """
  defexception [:message, :n, :min]

  @impl true
  def exception(value) do
    n = value[:n]
    min = value[:min]

    msg = ~s"""
    Cannot solve curve with only #{n} points. Need at least #{min}.
    """

    %__MODULE__{message: msg, n: n, min: min}
  end
end
