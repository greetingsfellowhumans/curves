defmodule Curves do
  alias Curves.Utils.Types, as: T
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Bezier.Predefined


  @moduledoc """
  ## Usage

  ```elixir
  # Create a bezier curve
  curve = Curves.define_bezier(:ease_in)

  # Find the {x, y} coordinate at 24% from the start
  {x, y} = Curves.solve!(curve, 0.24)
  ```

  For a list of all predefined bezier_types, use `Curves.Bezier.Predefined.list/0`

  ## Custom curves

  You can also create a custom bezier curve by passing in a list of `{x, y}` tuples. They can be any combination of floats and integers.

  ```elixir
  curve = Curves.define_bezier([
  # {x,   y}
    {0,   0},    # Knot 0. AKA the start point
    {0,   0.5},  # Control Point 0
    {0.8, 0.4},  # Control Point 1
    {1,   1}     # Knot 1. AKA the stop point
  ])

  t = 0.1234

  {x, y} = Curves.solve!(curve, t)
  ```

  ## Interactive tutorial
  Be sure to check out the livebooks to see these points turn into graphs.
  1. [Bezier Curves](bezier_curves.html).
  2. [Splines](splines.html).

  ## Transform

  See the `Curves.Transform` module for functions that allow you to move, resize, and rotate existing curves.

  ## Options
  All `define_*`, `solve*`, and `take*` functions can receive the following `opts`.

  | `key` | `default` | `description` |
  | --- | ---     | --- |
  | `:origin` | `{0, 0}` | Provides an offset. every point in the curve will automatically be increased by this {x, y} coordinate |
  | `:float_dtype` | `16` | One of `8`, `16`, `32`, `64`. Passed into Nx tensors as `{:f, dtype}`. |
  | `:force_percent` | `false` | If true, all results from `take` and `solve` are normalized as percentages of the max `y` coordinate defined  |

  """


  @doc ~s"""
  Build a new `Curves.Bezier.Curve`

  ## Options
  See [available opts](#module-options)

  ## Examples
      iex> c = Curves.define_bezier([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> is_struct(c, Curves.Bezier.Curve)
      true

  """
  @spec define_bezier(points :: T.point_list() | Predefined.curve_key(), T.define_opts()) :: Bezier.t()
  defdelegate define_bezier(points, opts \\ []), to: Bezier, as: :define


  # For internal use, not part of the public facing API.
  @doc false
  defdelegate define_spline(points, spline_type, opts \\ []), to: Curves.Spline.Curve, as: :define


  @doc ~s"""
  Return a `Curves.Spline.Curve` struct representing a `Curves.Spline.Type.BezierSpline`.
  Can later be passed into `solve/2`.

  ## Options
  See [available opts](#module-options)

  ```elixir
  points = [
    # P0
    [{5.0, 10.0},  # Knot
    {10.0, 10.0}], # control point 0

    # P1
    [{10.0, 5.0},  # Knot
      {5.0, 5.0},  # control point 0
      {15.0, 5.0}],# control point 1

    # P2
    [{15.0, 10.0}, # Knot
    {15.0, 6.0},  # control point 0
    {15.0, 14.0}  # control point 1
    ],

    # P3
    [{20.0, 15.0}, # Knot
    {18.0, 15.0}, # control point 0
    {23.0, 15.0}],# control point 1

    # P4
    [{30.0, 10.0}, # Knot
      {32.0, 5.0}] # control point 0
  ]
  curves = Curves.define_bezier_spline(points)
  {x, y} = Curves.solve!(curves, 0.518)
  ```
  """
  @spec define_bezier_spline(points :: list(T.point_list()), opts :: T.define_opts()) :: Spline.t()
  defdelegate define_bezier_spline(points, opts \\ []), to: Curves.Spline.Type.BezierSpline, as: :define


  @doc ~s"""
  Define a spline struct of type: `Curves.Spline.Type.BSpline`. 

  Only the knots need to be defined, the control points are calculated automatically.

  ## Options
  See [available opts](#module-options)

  ```elixir
  curve = Curves.define_b_spline([
    {0, 0},
    {1, 0},
    {1, 1},
    {0, 1},
    {0, 2},
    {1, 2},
  ])

  {x, y} = Curves.solve!(curve, 0.15)
  ```
  """
  @spec define_b_spline(T.point_list(), T.define_opts()) :: Spline.t()
  defdelegate define_b_spline(points, opts \\ []), to: Curves.Spline.Type.BSpline, as: :define


  @doc ~s"""
  Define a new `Curves.Spline.Type.Hermite` spline.
  Control points are calculated automatically based on the first derivative of each knot.

  ## Options
  See [available opts](#module-options)

  ## Example

  ```elixir
  curve = Curves.define_hermite([
    {5, 10},
    {10, 5},
    {15, 10},
    {20, 10},
    {25, 5},
    {30, 15},
  ])

  {x, y} = Curves.solve!(curve, 0.85)
  ```
  """
  @spec define_hermite(T.point_list(), T.define_opts()) :: Spline.t()
  defdelegate define_hermite(points, opts \\ []), to: Curves.Spline.Type.Hermite, as: :define


  @doc ~s"""
  Define a new `Curves.Spline.Type.CatmullRom`. Only the joins need to be defined, the control points are calculated automatically.

  ## Options
  See [available opts](#module-options)

  ```elixir
  curve = Curves.define_catmull_rom([
    {0, 0},
    {1, 0},
    {1, 1},
    {0, 1},
    {0, 2},
    {1, 2},
  ])

  {x, y} = Curves.solve!(curves, 0.5)
  ```
  """
  @spec define_catmull_rom(T.point_list(), T.define_opts()) :: Spline.t()
  defdelegate define_catmull_rom(points, opts \\ []), to: Curves.Spline.Type.CatmullRom, as: :define


  @doc ~s"""
  Given a `Curves.Bezier.Curve` or `Curves.Spline.Curve` struct, and `t`, find the point along the curve.

  For a bezier curve, `t` must be between 0.0 and 1.0.

  e.g. `t = 0.5` means the coordinate at 50% through the bezier curve.

  For splines, the range of `t` depends on the number of segments (number of knots - 1).

  e.g. `t = 0.5` means the coordinate at 50% through *the first segment*. But `t = 1.5` is 50% through the next segment.

  ## Examples
      iex> c = Curves.define_bezier([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> Curves.solve(c, 0.3)
      {:ok, {0.3695499897003174, 0.727199912071228}}

  ## Options
  * `:float_dtype` (default: nil) | If set to an integer, passes results to Float.round(_, precision)

  """
  @spec solve(Bezier.t() | Spline.t(), T.t(), T.opts()) :: {:ok, T.point_tuple()} | {:error, term()}
  def solve(curve, t, opts \\ []) do
    case curve do
      %Bezier{} -> Bezier.solve(curve, t, opts)
      %Spline{} -> Spline.solve(curve, t, opts)
    end
  end


  @doc ~s"""
  The raising version of `solve/3`
  """
  @spec solve!(Bezier.t() | Spline.t(), T.t(), T.opts()) :: T.point_tuple()
  def solve!(curve, t, opts \\ []) do
    case curve do
      %Bezier{} -> Bezier.solve!(curve, t, opts)
      %Spline{} -> Spline.solve!(curve, t, opts)
    end
  end


  @doc ~s"""
  Take `n` samples, evenly spaced, from the curve.
  """
  @spec take(Bezier.t() | Spline.t(), n :: pos_integer(), T.opts()) :: {:ok, T.point_list()} | {:error, term()}
  def take(curve, n, opts \\ []) do
    case curve do
      %Bezier{} -> Bezier.take(curve, n, opts)
      %Spline{} -> Spline.take(curve, n, opts)
    end
  end


  @doc ~s"""
  The raising version of `take/3`
  """
  @spec take!(Bezier.t() | Spline.t(), n :: pos_integer(), T.opts()) :: T.point_list()
  def take!(curve, n, opts \\ []) do
    case curve do
      %Bezier{} -> Bezier.take!(curve, n, opts)
      %Spline{} -> Spline.take!(curve, n, opts)
    end
  end


end
