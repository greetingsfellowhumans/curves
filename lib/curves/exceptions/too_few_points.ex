# Public API name. Credo guesses an `Out` prefix rule from OutOfBoundT/OutOfBoundU, which does not apply here.
# credo:disable-for-next-line Credo.Check.Consistency.ExceptionNames
defmodule Curves.Exceptions.TooFewPoints do
  @moduledoc false
  defexception [:message, :n, :min]

  @impl true
  def exception(value) do
    n = value[:n]
    min = value[:min]

    msg = ~s"""
    Cannot solve curve with only #{n} points. Need at least #{min}.
    """
    %__MODULE__{message: msg}
  end

  
end
