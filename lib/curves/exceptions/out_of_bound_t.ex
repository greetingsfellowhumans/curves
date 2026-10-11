defmodule Curves.Exceptions.OutOfBoundT do
  @moduledoc ~s"""
  Raised by `Curves.solve!/3` when a bezier curve is solved at a `t` outside `0.0..1.0`.
  `Curves.solve/3` returns `{:error, {:out_of_bounds, t}}` instead.

  Fields: `:message`, and `:t` (the value that was given).

  ```elixir
  try do
    Curves.solve!(Curves.define_bezier(:linear), 1.5)
  rescue
    e in Curves.Exceptions.OutOfBoundT -> e.t
  end
  #=> 1.5
  ```
  """
  defexception [:message, :t]

  @impl true
  def exception(value) do
    t = value[:t]

    msg = ~s"""
    The `t` value of a bezier curve must be between 0.0 and 1.0. Unfortunately the given `t` was #{t}

    Perhaps you were trying to pass in an x-coordinate? Think of `t` like a percentage of progress from the beginning to the end of the curve, rather than an actual coordinate.
    """

    %__MODULE__{message: msg, t: t}
  end
end
