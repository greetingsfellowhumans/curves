defmodule Curves.Utils.Errors do
  @moduledoc false
  # Errors shared by several modules, so their messages stay the same everywhere.

  # Raised when a function that takes a curve gets something else, e.g. `Curves.solve(:nope, 0.5)`.
  # It is the last branch of each `cond` that picks between Bezier and Spline.
  @spec raise_not_a_curve(term()) :: no_return()
  def raise_not_a_curve(term) do
    raise ArgumentError,
          "expected a Curves.Bezier.Curve, Curves.Spline.Curve or Curves.Polyline.Curve, got: #{inspect(term)}"
  end

  # Splines take their points as a list. Anything that can't be listed (like a single {x, y})
  # raises here, instead of a Protocol.UndefinedError deeper in. Returns the points.
  @spec check_points!(term()) :: Enumerable.t()
  def check_points!(points) when is_list(points) or is_map(points), do: points

  def check_points!(other),
    do: raise(ArgumentError, "a spline takes a list of points, got: #{inspect(other)}")
end
