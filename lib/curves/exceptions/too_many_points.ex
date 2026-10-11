# Public API name. Credo guesses an `Out` prefix rule from OutOfBoundT/OutOfBoundU, which does not apply here.
# credo:disable-for-next-line Credo.Check.Consistency.ExceptionNames
defmodule Curves.Exceptions.TooManyPoints do
  @moduledoc false
  defexception [:message, :n, :max]

  @impl true
  def exception(value) do
    n = value[:n]
    max = value[:max]

    msg = ~s"""
    Cannot solve a bezier curve with #{n} points. The maximum is #{max}.

    For longer paths, use a spline instead, such as `Curves.define_bezier_spline/2`.
    """

    %__MODULE__{message: msg}
  end
end
