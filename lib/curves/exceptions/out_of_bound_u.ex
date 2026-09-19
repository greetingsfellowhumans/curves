defmodule Curves.Exceptions.OutOfBoundU do
  defexception [:message, :max, :u]

  @impl true
  def exception(value) do
    max = value[:max]
    u = value[:u]

    msg = ~s"""
    The curve has #{round(max)} #{if max == 1.0, do: "segment", else: "segments"}, and therefore the value of `u` must be between 0.0 and #{max}.

    Unfortunately the given `u` was #{u}

    Perhaps you were trying to pass in an x-coordinate? Think of `u` like a percentage of progress from the beginning to the end of each segment of the curve, rather than an actual coordinate.

    In other words:
      `u = 0.5` would be 50% through segment 0
      `u = 2.5` would be 50% through segment 2
    """
    %__MODULE__{message: msg}
  end

  
end
