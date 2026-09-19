defmodule Curves.Exceptions.TooFewPoints do
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
