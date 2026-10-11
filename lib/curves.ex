defmodule Curves do
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Bezier.Predefined
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Types, as: T

  @moduledoc """
  ## Usage

  ```elixir
  # Create a bezier curve, and (optionally) apply any transformations you want.
  curve = Curves.define_bezier(:ease_in)
          |> Curves.Transform.set_scale(1.5)
          |> Curves.Transform.inc_position({10, 10})
          |> Curves.Transform.set_rotation(90)

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

  ## Precision

  Results are 64-bit floats (Elixir's own floats), so they're accurate to about 15 significant digits.
  The exact last digits are not part of the API: they may change in a minor release,
  for example when a calculation is sped up, so compare results with a small tolerance.

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
  | `:force_percent` | `false` | If true, `take` and `solve` rescale each coordinate to show where it sits between the lowest and highest point on that axis: the lowest becomes `0.0`, the highest becomes `1.0`, and halfway between them becomes `0.5`. The lowest and highest points are measured after any moves, scaling or rotation, including the `:origin` option. Curves that bend outside their points (e.g. Catmull-Rom) can return values slightly outside 0..1. If every point has the same value on an axis (a flat curve), that axis can't be rescaled, so it returns `0.5`. Rotating a flat curve adds tiny rounding errors, so that axis may no longer count as flat and can return values from `0.0` to `1.0`. |

  `:force_percent` can also be set for the whole app, e.g. `config :curves, force_percent: true`.
  Opts passed to a function always win over the app config.

  `:force_percent` is read on every `solve` and `take`, so changing it in the app config while running
  (e.g. with `Application.put_env/3`) applies to existing curves straight away.

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
  @spec define_bezier(points :: T.point_list() | Predefined.curve_key(), T.define_opts()) ::
          Bezier.t()
  defdelegate define_bezier(points, opts \\ []), to: Bezier, as: :define

  # For internal use, not part of the public facing API.
  @doc false
  @spec define_spline(list(list(T.point_tuple())), atom(), T.opts()) :: Spline.t()
  defdelegate define_spline(points, spline_type, opts \\ []), to: Curves.Spline.Curve, as: :define

  @doc ~s"""
  Return a `Curves.Spline.Curve` struct representing a `Curves.Spline.Type.BezierSpline`.
  Can later be passed into `solve/2`.

  ## Options
  See [available opts](#module-options)

  Each point is a list: its knot, then up to two control points (`[knot]`, `[knot, c]` or `[knot, c0, c1]`).
  Any other shape, or an empty list, raises an `ArgumentError`.

  ## Examples
      iex> curve = Curves.define_bezier_spline([
      ...>   [{5.0, 10.0}, {10.0, 10.0}],
      ...>   [{10.0, 5.0}, {5.0, 5.0}, {15.0, 5.0}],
      ...>   [{15.0, 10.0}, {15.0, 6.0}, {15.0, 14.0}],
      ...>   [{20.0, 15.0}, {18.0, 15.0}, {23.0, 15.0}],
      ...>   [{30.0, 10.0}, {32.0, 5.0}]
      ...> ])
      iex> Curves.max_u(curve)
      4.0
      iex> Curves.solve!(curve, 1.0)
      {10.0, 5.0}
      iex> Curves.define_bezier_spline([])
      ** (ArgumentError) a spline needs at least 1 point, got none
  """
  @spec define_bezier_spline(points :: list(T.point_list()), opts :: T.define_opts()) ::
          Spline.t()
  defdelegate define_bezier_spline(points, opts \\ []),
    to: Curves.Spline.Type.BezierSpline,
    as: :define

  @doc ~s"""
  Define a spline struct of type: `Curves.Spline.Type.BSpline`.

  Only the knots need to be defined, the control points are calculated automatically.
  Needs at least 4 points; `n` points give `n - 3` segments. Fewer raise an `ArgumentError`.

  ## Options
  See [available opts](#module-options)

  ## Examples
      iex> curve = Curves.define_b_spline([{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}])
      iex> Curves.max_u(curve)
      3.0
      iex> {x, y} = Curves.solve!(curve, 0.0)
      iex> {Float.round(x, 4), Float.round(y, 4)}
      {0.8333, 0.1667}
      iex> Curves.define_b_spline([{0, 0}, {1, 0}, {1, 1}])
      ** (ArgumentError) a B-spline needs at least 4 points, got 3
  """
  @spec define_b_spline(T.point_list(), T.define_opts()) :: Spline.t()
  defdelegate define_b_spline(points, opts \\ []), to: Curves.Spline.Type.BSpline, as: :define

  @doc ~s"""
  Define a new `Curves.Spline.Type.Hermite` spline: a smooth curve through every knot,
  leaving each one along the tangent you give it.

  Each point is `[knot, tangent]`, both `{x, y}`. The tangent is the curve's velocity at that knot
  per unit of `u`. Needs at least 2 points; `n` points give `n - 1` segments.

  ## Options
  See [available opts](#module-options)

  ## Examples
      iex> curve = Curves.define_hermite([[{0, 0}, {4, 0}], [{2, 2}, {0, 4}], [{4, 0}, {4, 0}]])
      iex> Curves.max_u(curve)
      2.0
      iex> Curves.solve!(curve, 1.0)
      {2.0, 2.0}
      iex> Curves.solve!(curve, 0.5)
      {1.5, 0.5}
  """
  @spec define_hermite(list([T.point_tuple()]), T.define_opts()) :: Spline.t()
  defdelegate define_hermite(points, opts \\ []), to: Curves.Spline.Type.Hermite, as: :define

  @doc ~s"""
  Define a new `Curves.Spline.Type.CatmullRom`. Only the joins need to be defined, the control points are calculated automatically.
  An empty list raises an `ArgumentError`.

  ## Options
  See [available opts](#module-options)

  ## Examples
      iex> curve = Curves.define_catmull_rom([{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}])
      iex> Curves.solve!(curve, 1.0)
      {1.0, 0.0}
      iex> Curves.solve!(curve, 0.5)
      {0.5625, -0.0625}
      iex> Curves.define_catmull_rom([])
      ** (ArgumentError) a spline needs at least 1 point, got none
  """
  @spec define_catmull_rom(T.point_list(), T.define_opts()) :: Spline.t()
  defdelegate define_catmull_rom(points, opts \\ []),
    to: Curves.Spline.Type.CatmullRom,
    as: :define

  @doc ~s"""
  Given a `Curves.Bezier.Curve` or `Curves.Spline.Curve` struct, and `t`, find the point along the curve.

  For a bezier curve, `t` must be between 0.0 and 1.0.

  e.g. `t = 0.5` means the coordinate at 50% through the bezier curve.

  For splines, the range of `t` depends on the number of segments (number of knots - 1).

  e.g. `t = 0.5` means the coordinate at 50% through *the first segment*. But `t = 1.5` is 50% through the next segment.

  ## Examples
      iex> c = Curves.define_bezier([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> {:ok, {x, y}} = Curves.solve(c, 0.3)
      iex> {Float.round(x, 3), Float.round(y, 3)}
      {0.37, 0.727}
      iex> Curves.solve(c, 1.5)
      {:error, {:out_of_bounds, 1.5}}

  ## Options
  See [available opts](#module-options).
  """
  @spec solve(Bezier.t() | Spline.t(), T.t(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, term()}
  def solve(curve, t, opts \\ []) do
    # Dispatch with is_struct/2, not a %Bezier{} pattern (same in solve!/3, take/3, take!/3).
    # A pattern turns the opaque curve into a plain map in Dialyzer's eyes, and passing
    # that on to Bezier/Spline warns "call without opaqueness".
    cond do
      is_struct(curve, Bezier) -> Bezier.solve(curve, t, opts)
      is_struct(curve, Spline) -> Spline.solve(curve, t, opts)
    end
  end

  @doc ~s"""
  The raising version of `solve/3`: returns the `{x, y}` point, or raises one of the
  `Curves.Exceptions` errors (e.g. `Curves.Exceptions.OutOfBoundT`).

  ## Examples
      iex> Curves.solve!(Curves.define_bezier(:linear), 0.5)
      {0.5, 0.5}
  """
  @spec solve!(Bezier.t() | Spline.t(), T.t(), T.opts()) :: T.point_tuple()
  def solve!(curve, t, opts \\ []) do
    cond do
      is_struct(curve, Bezier) -> Bezier.solve!(curve, t, opts)
      is_struct(curve, Spline) -> Spline.solve!(curve, t, opts)
    end
  end

  @doc ~s"""
  The highest `t` (bezier) or `u` (spline) that `solve/3` accepts. Every curve starts at `0.0`.

  Beziers always end at `1.0`. A spline ends at one unit per segment,
  so `u = 1.0` is the end of its first segment and `u = max_u(curve)` is the end of the curve.

  ## Examples
      iex> Curves.max_u(Curves.define_bezier(:ease_in))
      1.0
      iex> Curves.max_u(Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}]))
      3.0
  """
  @spec max_u(Bezier.t() | Spline.t()) :: float()
  def max_u(%Bezier{}), do: 1.0
  def max_u(%Spline{max_u: max_u}), do: max_u

  @doc ~s"""
  Take `n` samples, evenly spaced along the curve.

  The samples are at `t = 1/n, 2/n, ... 1.0` for a bezier (or the same steps up to
  `max_u/1` for a spline). The start, `t = 0`, is not included: call `solve/3` with `0.0` if you need it.
  `n` must be a positive integer, otherwise it raises an `ArgumentError`.

  ## Examples
      iex> Curves.take(Curves.define_bezier(:linear), 4)
      {:ok, [{0.25, 0.25}, {0.5, 0.5}, {0.75, 0.75}, {1.0, 1.0}]}
      iex> Curves.take(Curves.define_bezier([{0, 0}, {1, 1}, {2, 2}, {3, 3}, {4, 4}]), 2)
      {:error, {:too_many_points, 5, 4}}
      iex> Curves.take(Curves.define_bezier(:linear), 0)
      ** (ArgumentError) n must be a positive integer (the number of samples), got: 0
  """
  @spec take(Bezier.t() | Spline.t(), n :: pos_integer(), T.opts()) ::
          {:ok, T.point_list()} | {:error, term()}
  def take(curve, n, opts \\ [])
  def take(_curve, n, _opts) when not is_integer(n) or n < 1, do: raise_bad_count(n)

  def take(curve, n, opts) do
    cond do
      is_struct(curve, Bezier) -> Bezier.take(curve, n, opts)
      is_struct(curve, Spline) -> Spline.take(curve, n, opts)
    end
  end

  @doc ~s"""
  The raising version of `take/3`: returns the list of points, or raises one of the `Curves.Exceptions` errors.

  ## Examples
      iex> Curves.take!(Curves.define_bezier([{0, 0}, {1, 2}, {2, 0}]), 2)
      [{1.0, 1.0}, {2.0, 0.0}]
  """
  @spec take!(Bezier.t() | Spline.t(), n :: pos_integer(), T.opts()) :: T.point_list()
  def take!(curve, n, opts \\ [])
  def take!(_curve, n, _opts) when not is_integer(n) or n < 1, do: raise_bad_count(n)

  def take!(curve, n, opts) do
    cond do
      is_struct(curve, Bezier) -> Bezier.take!(curve, n, opts)
      is_struct(curve, Spline) -> Spline.take!(curve, n, opts)
    end
  end

  # take/3 and take!/3 divide by n, and 1..n counts down when n < 1, so anything but a
  # positive integer is rejected up front.
  @spec raise_bad_count(term()) :: no_return()
  defp raise_bad_count(n) do
    raise ArgumentError,
          "n must be a positive integer (the number of samples), got: #{inspect(n)}"
  end
end
