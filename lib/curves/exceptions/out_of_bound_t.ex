defmodule Curves.Exceptions.OutOfBoundT do
  defexception [:message, :t]

  @impl true
  def exception(value) do
    t = value[:t]

    msg = ~s"""
    The `t` value of a bezier curve must be between 0.0 and 1.0. Unfortunately the given `t` was #{t}

    Perhaps you were trying to pass in an x-coordinate? Think of `t` like a percentage of progress from the beginning to the end of the curve, rather than an actual coordinate.
    """
    %__MODULE__{message: msg}
  end

  
end
