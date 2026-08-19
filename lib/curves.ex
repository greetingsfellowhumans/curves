defmodule Curves do
  alias Curves.Utils.Types, as: T
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Bezier.Predefined

  @typedoc ~s"""
  Float between 0.0 and 1.0, representing a percentage of progress from the first to last point.
  """
  @type t :: float()

  @moduledoc """
  The best way to explore this library is through the interactive [livebook](bezier_curves.html).

  ## Quickstart

  The fastest way to get started is with the predefined bezier curves.
  ```elixir
  bezier_type = :ease_in
  curve = Curves.define_bezier(bezier_type)

  t = 0.24 # i.e. 24%  from the beginning to the end of the curve.
  {x, y} = Curves.solve!(curve, t)

  assert is_float(x)
  assert is_float(y)
  ```

  For a list of all predefined bezier_types, use `Curves.Bezier.Predefined.list/0`

  ## Custom curves

  You can also create a custom bezier curve by passing in a list of `{x, y}` tuples. They can be any combination of floats and integers.

  ```elixir
  curve = Curves.define_bezier([
  # {x,   y}
    {0,   0},
    {0,   0.5},
    {0.8, 0.4},
    {1,   1}
  ])

  t = 0.248

  {x, y} = Curves.solve!(curve, t)

  assert is_float(x)
  assert is_float(y)
  ```

  """

  @doc ~s"""
  Build a new Bezier Curve struct.

  ## Examples
      iex> c = Curves.define_bezier([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> is_struct(c, Curves.Bezier.Curve)
      true
  """
  @spec define_bezier(points :: T.point_list() | Predefined.curve_key(), T.opts()) :: Bezier.t()
  defdelegate define_bezier(points, opts \\ []), to: Bezier, as: :define

  @doc ~s"""
  Given a struct, and t, find the point along the curve

  ## Examples
      iex> c = Curves.define_bezier([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> Curves.solve(c, 0.3)
      {:ok, {0.3695499897003174, 0.727199912071228}}

  ## Options
  * `:float_dtype` (default: nil) | If set to an integer, passes results to Float.round(_, precision)

  """
  @spec solve(Bezier.t(), t(), T.opts()) :: {:ok, T.point_tuple()} | {:error, term()}
  defdelegate solve(curve, t, opts \\ []), to: Curves.Bezier.Curve

  @doc ~s"""
  The raising version of `solve/3`
  """
  @spec solve!(Bezier.t(), t(), T.opts()) :: T.point_tuple()
  defdelegate solve!(curve, t, opts \\ []), to: Curves.Bezier.Curve

  @doc ~s"""
  Take `n` samples, evenly spaced, from the curve.
  """
  @spec take(Bezier.t(), n :: pos_integer(), T.opts()) :: {:ok, T.point_list()} | {:error, term()}
  defdelegate take(curve, n, opts \\ []), to: Curves.Bezier.Curve
  @doc ~s"""
  The raising version of `take/3`
  """
  @spec take!(Bezier.t(), n :: pos_integer(), T.opts()) :: T.point_list()
  defdelegate take!(curve, n, opts \\ []), to: Curves.Bezier.Curve

end
