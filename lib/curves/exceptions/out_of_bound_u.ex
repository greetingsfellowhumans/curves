defmodule Curves.Exceptions.OutOfBoundU do
  defexception [:message, :max, :u]

  @impl true
  def exception(value) do
    max = value[:max]
    u = value[:u]

    msg = ~s"""
    The curve has #{round(max)} #{if max == 1.0, do: "segment", else: "segments"}, and therefore the value of `u` must be between 0.0 and #{max}.

    Unfortunately the given `u` was #{u}
    """
    %__MODULE__{message: msg}
  end

  
end
