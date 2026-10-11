# Public API name. Credo guesses an `Out` prefix rule from OutOfBoundT/OutOfBoundU, which does not apply here.
# credo:disable-for-next-line Credo.Check.Consistency.ExceptionNames
defmodule Curves.Exceptions.TooManyPoints do
  @moduledoc ~s"""
  Raised by `Curves.solve!/3` and `Curves.take!/3` for a bezier curve defined with more than 4 points.
  `Curves.solve/3` returns `{:error, {:too_many_points, n, 4}}` instead. For longer paths, use a spline.

  Fields: `:message`, `:n` (how many points the curve has) and `:max` (the maximum, 4).
  """
  defexception [:message, :n, :max]

  @impl true
  def exception(value) do
    n = value[:n]
    max = value[:max]

    msg = ~s"""
    Cannot solve a bezier curve with #{n} points. The maximum is #{max}.

    For longer paths, use a spline instead, such as `Curves.define_bezier_spline/2`.
    """

    %__MODULE__{message: msg, n: n, max: max}
  end
end
