defmodule Curves do
  @type coord :: float() | integer()
  @type point_tuple :: {x :: coord(), y :: coord()}
  @type point_list :: list(point_tuple())
  @type curve :: Curves.Bezier.Curve.t()
  @type opts :: keyword()
  @type t :: float()
  @type predefined_bezier_type :: atom()
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
      iex> is_struct(c, Curves.Curve)
      true
  """
  @spec define_bezier(points :: point_list() | predefined_bezier_type(), opts :: list()) :: curve()
  defdelegate define_bezier(points, opts \\ []), to: Curves.Bezier.Curve, as: :define

  @doc ~s"""
  Given a struct, and t, find the point along the curve

  ## Examples
      iex> c = Curves.define_bezier([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> Curves.solve(c, 0.3)
      {:ok, {0.3695499897003174, 0.727199912071228}}

  ## Options
  * `:float_dtype` (default: nil) | If set to an integer, passes results to Float.round(_, precision)

  """
  @spec solve(curve(), t(), opts()) :: {:ok, point_tuple()} | {:error, term()}
  defdelegate solve(curve, t, opts \\ []), to: Curves.Bezier.Curve

  @doc ~s"""
  The raising version of `solve/3`
  """
  @spec solve!(curve(), t(), opts()) :: point_tuple()
  defdelegate solve!(curve, t, opts \\ []), to: Curves.Bezier.Curve

  @doc ~s"""
  Take `n` samples, evenly spaced, from the curve.
  """
  @spec take(curve(), n :: pos_integer(), opts()) :: {:ok, point_list()} | {:error, term()}
  defdelegate take(curve, n, opts \\ []), to: Curves.Bezier.Curve
  @doc ~s"""
  The raising version of `take/3`
  """
  @spec take!(curve(), n :: pos_integer(), opts()) :: point_list()
  defdelegate take!(curve, n, opts \\ []), to: Curves.Bezier.Curve

  @doc ~s"""
  List of atoms that can be passed into `define_bezier/2`.

  ## Examples
      iex> li = Curves.list_predefined_bezier_types()
      iex> :ease_in_cubic in li
      true
  """
  @spec list_predefined_bezier_types() :: list(predefined_bezier_type())
  defdelegate list_predefined_bezier_types(), to: Curves.Bezier.Predefined, as: :list
end
