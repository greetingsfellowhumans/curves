defmodule Curves do
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Bezier.Predefined
  alias Curves.Polyline.Curve, as: Polyline
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Types, as: T
  alias Curves.Utils.Errors

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

  ## Tutorial

  New to curves? The tutorial has lots of pictures, and each chapter is also an interactive Livebook:

  1. [Your first curve](first_curve.html): `t`, `solve`, `take`, and the ready-made curves.
  2. [Bezier curves](bezier_curves.html): how control points shape a curve.
  3. [Splines](splines.html): polylines and the nine kinds of spline, and when to use each.
  4. [Transforms and drawing](transforms.html): moving, scaling and rotating, and `Curves.Svg`.

  Not sure which curve to use? [Choosing a curve](choosing_a_curve.html) compares them all, with
  real-world examples of each.


  ## Reading SVGs

  `from_svg/2` reads the shapes in an SVG into a `Curves.Drawing` of curves, and `from_svg_path/2`
  reads the path data of a single `<path>`.

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
  Build a new `Curves.Bezier.Curve` from a list of `{x, y}` points, or from the name of a
  predefined curve (see `Curves.Bezier.Predefined.list/0`). Anything else, or a name that
  isn't predefined, raises an `ArgumentError`.

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

  Each point is a knot, then the control points of the curve to the next knot, like an SVG path:
  `[knot]` is a straight line (SVG `L`), `[knot, c]` a quadratic curve (`Q`) and `[knot, c0, c1]`
  a cubic curve (`C`). The last point only ends the curve, so it must be `[knot]`.
  Any other shape, or an empty list, raises an `ArgumentError`.

  `[knot, {:arc, rx, ry, rotation, large_arc, sweep}]` is an elliptical arc to the next knot, exactly
  like SVG's `A rx ry rotation large-arc-flag sweep-flag x y`, with `true`/`false` for the flags and
  the rotation in degrees. See `Curves.Spline.Type.BezierSpline` for what the flags do.

  ## Examples
      iex> curve = Curves.define_bezier_spline([
      ...>   [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],
      ...>   [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}],
      ...>   [{15.0, 10.0}, {15.0, 14.0}, {18.0, 15.0}],
      ...>   [{20.0, 15.0}, {23.0, 15.0}, {32.0, 5.0}],
      ...>   [{30.0, 10.0}]
      ...> ])
      iex> Curves.max_u(curve)
      4.0
      iex> Curves.solve!(curve, 1.0)
      {10.0, 5.0}
      iex> Curves.define_bezier_spline([])
      ** (ArgumentError) a spline needs at least 1 point, got none

  A line, then a half circle (SVG `M 0 0 L 10 0 A 5 5 0 0 1 10 10`):

      iex> curve = Curves.define_bezier_spline([[{0, 0}], [{10, 0}, {:arc, 5, 5, 0, false, true}], [{10, 10}]])
      iex> Curves.solve!(curve, 1.5)
      {15.0, 5.0}
      iex> Curves.solve!(curve, 2.0)
      {10.0, 10.0}
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
  Define a new `Curves.Spline.Type.Cardinal` spline: a Catmull-Rom spline through every knot, with
  a `:tension` that sets how tightly it bends at each knot.

  `n` knots give `n - 1` segments. An empty list raises an `ArgumentError`.

  ## Options
  `:tension` (default `0.0`): `0.0` is exactly `define_catmull_rom/2`. Higher values bend more
  tightly at each knot, and `1.0` gives straight lines that slow down at each knot. A tension that
  isn't a number raises an `ArgumentError`.

  Also see [available opts](#module-options).

  ## Examples
      iex> knots = [{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}]
      iex> curve = Curves.define_cardinal(knots, tension: 0.5)
      iex> Curves.max_u(curve)
      4.0
      iex> Curves.solve!(curve, 1.0)
      {2.0, 3.0}
      iex> Curves.solve!(curve, 0.5)
      {1.0, 1.65625}
      iex> Curves.solve!(Curves.define_cardinal(knots), 0.5) == Curves.solve!(Curves.define_catmull_rom(knots), 0.5)
      true
      iex> Curves.define_cardinal(knots, tension: :high)
      ** (ArgumentError) the :tension option must be a number, got: :high
  """
  @spec define_cardinal(T.point_list(), T.cardinal_opts()) :: Spline.t()
  defdelegate define_cardinal(points, opts \\ []), to: Curves.Spline.Type.Cardinal, as: :define

  @doc ~s"""
  Define a new `Curves.Spline.Type.CentripetalCatmullRom` spline: a Catmull-Rom spline through every
  knot that takes the distances between knots into account, so it never makes little loops or
  sharp points, even when some knots are bunched up.

  `n` knots give `n - 1` segments. An empty list raises an `ArgumentError`.

  ## Options
  `:alpha` (default `0.5`), between `0.0` and `1.0`: `0.5` is centripetal, `0.0` is exactly
  `define_catmull_rom/2`, and `1.0` is chordal. Anything else raises an `ArgumentError`.

  Also see [available opts](#module-options).

  ## Examples
      iex> curve = Curves.define_centripetal_catmull_rom([{0, 0}, {10, 10}, {10.5, 10}, {20, 0}])
      iex> Curves.max_u(curve)
      3.0
      iex> Curves.solve!(curve, 1.0)
      {10.0, 10.0}
      iex> Curves.define_centripetal_catmull_rom([{0, 0}, {1, 3}], alpha: 2)
      ** (ArgumentError) the :alpha option must be between 0.0 and 1.0, got: 2.0
  """
  @spec define_centripetal_catmull_rom(T.point_list(), T.centripetal_opts()) :: Spline.t()
  defdelegate define_centripetal_catmull_rom(points, opts \\ []),
    to: Curves.Spline.Type.CentripetalCatmullRom,
    as: :define

  @doc ~s"""
  Define a new `Curves.Spline.Type.KochanekBartels` (TCB) spline: a Catmull-Rom spline through
  every knot, with three dials that change how it passes through each knot.

  `n` knots give `n - 1` segments. An empty list raises an `ArgumentError`.

  ## Options
  Each dial is a number, usually between `-1.0` and `1.0`, and `0.0` by default. With all three at
  `0.0` it is exactly `define_catmull_rom/2`. A dial that isn't a number raises an `ArgumentError`.

  * `:tension` - how tightly it bends at each knot, as in `define_cardinal/2`.
  * `:continuity` - below `0.0` makes sharper corners (`-1.0` turns like a polyline), above `0.0`
    makes corners that bulge out.
  * `:bias` - below `0.0` turns early, towards the next knot; above `0.0` turns late, overshooting.

  Also see [available opts](#module-options).

  ## Examples
      iex> knots = [{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}]
      iex> curve = Curves.define_kochanek_bartels(knots, continuity: -1.0)
      iex> Curves.solve!(curve, 1.0)
      {2.0, 3.0}
      iex> Curves.solve!(curve, 0.5)
      {1.0, 1.5}
      iex> Curves.solve!(Curves.define_kochanek_bartels(knots), 0.5) == Curves.solve!(Curves.define_catmull_rom(knots), 0.5)
      true
  """
  @spec define_kochanek_bartels(T.point_list(), T.kochanek_bartels_opts()) :: Spline.t()
  defdelegate define_kochanek_bartels(points, opts \\ []),
    to: Curves.Spline.Type.KochanekBartels,
    as: :define

  @doc ~s"""
  Define a new `Curves.Spline.Type.Monotone` spline: a smooth curve through data points that never
  overshoots them, the usual way to smooth a line chart.

  Each knot is a data point, so its `x` must be bigger than the knot before it (or every `x`
  smaller), otherwise it raises an `ArgumentError`. Between two knots the curve only goes up, only
  goes down, or stays flat. `n` knots give `n - 1` segments, and within each one `x` moves at a
  steady speed.

  ## Options
  See [available opts](#module-options)

  ## Examples
      iex> curve = Curves.define_monotone([{0, 0}, {1, 0}, {2, 3}, {3, 3}, {4, 1}])
      iex> Curves.max_u(curve)
      4.0
      iex> Curves.solve!(curve, 0.5)
      {0.5, 0.0}
      iex> Curves.solve!(curve, 1.5)
      {1.5, 1.5}
      iex> Curves.define_monotone([{0, 0}, {2, 1}, {1, 2}])
      ** (ArgumentError) the knots of a monotone spline must have x always increasing (or always decreasing), so each knot is a data point. Got x values: [0.0, 2.0, 1.0]. See Curves.define_monotone/2.
  """
  @spec define_monotone(T.point_list(), T.define_opts()) :: Spline.t()
  defdelegate define_monotone(points, opts \\ []), to: Curves.Spline.Type.Monotone, as: :define

  @doc ~s"""
  Define a new `Curves.Spline.Type.NaturalCubic` spline: the smoothest curve through every knot.
  Its bend changes smoothly everywhere, and it straightens out at both ends.

  Every knot affects the whole curve, so moving one knot changes every segment a little.
  `n` knots give `n - 1` segments. An empty list raises an `ArgumentError`.

  ## Options
  See [available opts](#module-options)

  ## Examples
      iex> curve = Curves.define_natural_cubic([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])
      iex> Curves.max_u(curve)
      4.0
      iex> Curves.solve!(curve, 1.0)
      {2.0, 3.0}
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> {Float.round(x, 4), Float.round(y, 4)}
      {1.0, 2.1696}
  """
  @spec define_natural_cubic(T.point_list(), T.define_opts()) :: Spline.t()
  defdelegate define_natural_cubic(points, opts \\ []),
    to: Curves.Spline.Type.NaturalCubic,
    as: :define

  @doc ~s"""
  Define an ellipse, or an arc of one: a `Curves.Spline.Type.Ellipse` centred on `center`, with
  radii `{rx, ry}` (numbers that are 0 or more; anything else raises an `ArgumentError`).

  It is one segment, so `u` goes from `0.0` to `1.0`. By default it goes once all the way round,
  starting at `center + {rx, 0}` like SVG's `<ellipse>`, and ends exactly where it started.

  ## Options
  All in degrees:

  * `:rotation` (default `0`) - tilts the ellipse's x axis, turning it around its centre.
  * `:from` and `:to` (defaults `0` and `360`) - the angles the curve starts and ends at, measured
    from the ellipse's x axis, to make an arc. When `:to` is bigger, the angle goes up: anticlockwise
    in Curves' pictures (y up), clockwise on an SVG screen (y down). When it is smaller, the other way.

  Also see [available opts](#module-options).

  ## Examples
      iex> curve = Curves.define_ellipse({1, 2}, {4, 2})
      iex> Curves.max_u(curve)
      1.0
      iex> Curves.solve!(curve, 0.0)
      {5.0, 2.0}
      iex> Curves.solve!(curve, 1.0)
      {5.0, 2.0}
      iex> {x, y} = Curves.solve!(curve, 0.25)
      iex> {Float.round(x, 6), Float.round(y, 6)}
      {1.0, 4.0}
      iex> Curves.define_ellipse({0, 0}, {-1, 2})
      ** (ArgumentError) the radii of an ellipse must be {rx, ry}, two numbers that are 0 or more, got: {-1, 2}
  """
  @spec define_ellipse(T.point_tuple(), {number(), number()}, T.ellipse_opts()) :: Spline.t()
  def define_ellipse(center, radii, opts \\ []),
    do: Curves.Spline.Type.Ellipse.define({center, radii}, opts)

  @doc ~s"""
  Define a circle, or an arc of one: `define_ellipse/3` with both radii `r`. It takes the same
  options, so `:from` and `:to` (in degrees) make an arc, like a canvas's `arc()`.

  ## Examples
      iex> curve = Curves.define_circle({0, 0}, 2, from: 90, to: 180)
      iex> {x, y} = Curves.solve!(curve, 1.0)
      iex> {Float.round(x, 6), Float.round(y, 6)}
      {-2.0, 0.0}
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> {Float.round(x, 4), Float.round(y, 4)}
      {-1.4142, 1.4142}
  """
  @spec define_circle(T.point_tuple(), number(), T.ellipse_opts()) :: Spline.t()
  defdelegate define_circle(center, r, opts \\ []), to: Curves.Spline.Type.Ellipse

  @doc ~s"""
  Define a `Curves.Polyline.Curve`: knots joined by straight lines, like SVG's `<polyline>`.

  Like a spline, it is solved with `u`: each line adds one to it, so `u = 1.0` is the second knot and
  `max_u/1` is the last one. Within a line the speed is steady: `u = 0.5` is exactly halfway along the
  first line. An empty list raises an `ArgumentError`.

  ## Options
  See [available opts](#module-options)

  ## Examples
      iex> curve = Curves.define_polyline([{0, 0}, {2, 4}, {6, 4}])
      iex> Curves.max_u(curve)
      2.0
      iex> Curves.solve!(curve, 0.5)
      {1.0, 2.0}
      iex> Curves.solve!(curve, 1.25)
      {3.0, 4.0}
      iex> Curves.define_polyline([])
      ** (ArgumentError) a polyline needs at least 1 point, got none
  """
  @spec define_polyline(T.point_list(), T.define_opts()) :: Polyline.t()
  defdelegate define_polyline(points, opts \\ []), to: Polyline, as: :define

  @doc ~s"""
  Read an SVG document into a `Curves.Drawing`: every shape in it (`<path>`, `<rect>`, `<circle>`,
  `<ellipse>`, `<line>`, `<polyline>` and `<polygon>`), each as one curve per continuous piece.

  Paths become bezier splines with exact arcs, rectangles and circles become splines too, and
  lines, polylines and polygons become polylines (see `Curves.Drawing.Subpath`). Every `transform`,
  on a shape or on the groups around it, is applied to the curves exactly, even skews. Anything
  that can't be read as curves is listed in the drawing's `:skipped` field, with the reason.

  The drawing keeps the SVG's structure: its groups, its shapes' styles, and everything that isn't
  curves (text, `<defs>`, `<style>`, ...) as markup. So `Curves.Svg.save!/3` draws it again just as
  it was, and you can change its curves in between.

  The coordinates are SVG's own, where y goes down the screen. Curves' own pictures of curves
  (`Curves.Svg`'s `:inspect` mode) draw y going up, as in maths, so pass `flip_y: true` to turn the
  drawing's y around for those.

  Reading is safe on SVGs from anywhere: it has no XML library, never creates atoms from the input,
  and reads in one pass. `<script>` and `<foreignObject>` elements, animations of links and event
  handlers, event attributes (`onclick`, ...) and `javascript:` links (even disguised with spaces)
  are never kept, so they aren't in a drawing drawn again, and the markup it keeps is always well
  formed. That isn't a full
  sanitizer, though: don't show untrusted SVGs to people without one. Input that isn't a string, or
  has no `<svg>` element, raises an `ArgumentError`.

  Not read as curves (but kept as markup, so they are still drawn again): text, images, `<use>`, a
  nested `<svg>`, and shapes with sizes in units other than `px`. CSS (`style` attributes and
  `<style>`) isn't applied to the curves, but it is kept with them.

  ## Options
  * `:flip_y` (default `false`) - mirror every y, so y goes up.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg viewBox="0 0 20 10"><rect x="1" y="2" width="4" height="3" fill="red"/></svg>))
      iex> drawing.view_box
      {0.0, 0.0, 20.0, 10.0}
      iex> [%Curves.Drawing.Shape{element: :rect, subpaths: [subpath]} = rect] = Curves.Drawing.shapes(drawing)
      iex> rect.attributes["fill"]
      "red"
      iex> Curves.solve!(subpath.curve, 1.0)
      {5.0, 2.0}

  Transforms are applied, and what can't be read is listed:

      iex> drawing = Curves.from_svg(~s[<svg><g transform="translate(10 0)"><line x2="5"/></g><text>Hi</text></svg>])
      iex> [line] = Curves.Drawing.curves(drawing)
      iex> Curves.solve!(line, 1.0)
      {15.0, 0.0}
      iex> drawing.skipped
      [%{element: "text", id: nil, reason: :not_curves, kept: :as_markup}]
  """
  @spec from_svg(String.t(), keyword()) :: Curves.Drawing.t()
  def from_svg(svg, opts \\ []), do: Curves.Svg.Import.from_svg(svg, opts)

  @doc ~s"""
  Read SVG path data (a `<path>` element's `d` attribute) into a list of `Curves.Drawing.Subpath`,
  one per continuous piece, each with a bezier spline curve. Every path command works, absolute and
  relative: `M L H V C S Q T A Z`. Bad path data raises an `ArgumentError` saying where.

  ## Options
  * `:flip_y` (default `false`) - mirror every y, so y goes up. See `from_svg/2`.

  ## Examples
      iex> [subpath] = Curves.from_svg_path("M 0 0 L 10 0 A 5 5 0 0 1 10 10 Z")
      iex> subpath.closed
      true
      iex> Curves.solve!(subpath.curve, 1.5)
      {15.0, 5.0}
      iex> Curves.from_svg_path("M 0 0 L 10")
      ** (ArgumentError) invalid path data: expected a number, got: the end in the L command
  """
  @spec from_svg_path(String.t(), keyword()) :: list(Curves.Drawing.Subpath.t())
  def from_svg_path(data, opts \\ []), do: Curves.Svg.Import.from_path(data, opts)

  @doc ~s"""
  Given a curve (`Curves.Bezier.Curve`, `Curves.Spline.Curve` or `Curves.Polyline.Curve`) and `t`, find the point along it.

  For a bezier curve, `t` must be between 0.0 and 1.0. A `t` that isn't a number raises an `ArgumentError`.

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
  @spec solve(Bezier.t() | Spline.t() | Polyline.t(), T.t(), T.opts()) ::
          {:ok, T.point_tuple()} | {:error, term()}
  def solve(curve, t, opts \\ []) do
    # Dispatch with is_struct/2, not a %Bezier{} pattern (same in solve!/3, take/3, take!/3).
    # A pattern turns the opaque curve into a plain map in Dialyzer's eyes, and passing
    # that on to Bezier/Spline warns "call without opaqueness".
    cond do
      is_struct(curve, Bezier) -> Bezier.solve(curve, t, opts)
      is_struct(curve, Spline) -> Spline.solve(curve, t, opts)
      is_struct(curve, Polyline) -> Polyline.solve(curve, t, opts)
      true -> Errors.raise_not_a_curve(curve)
    end
  end

  @doc ~s"""
  The raising version of `solve/3`: returns the `{x, y}` point, or raises one of the
  `Curves.Exceptions` errors (e.g. `Curves.Exceptions.OutOfBoundT`).

  ## Examples
      iex> Curves.solve!(Curves.define_bezier(:linear), 0.5)
      {0.5, 0.5}
  """
  @spec solve!(Bezier.t() | Spline.t() | Polyline.t(), T.t(), T.opts()) :: T.point_tuple()
  def solve!(curve, t, opts \\ []) do
    cond do
      is_struct(curve, Bezier) -> Bezier.solve!(curve, t, opts)
      is_struct(curve, Spline) -> Spline.solve!(curve, t, opts)
      is_struct(curve, Polyline) -> Polyline.solve!(curve, t, opts)
      true -> Errors.raise_not_a_curve(curve)
    end
  end

  @doc ~s"""
  The highest `t` (bezier) or `u` (spline) that `solve/3` accepts. Every curve starts at `0.0`.

  Beziers always end at `1.0`. Splines and polylines end at one unit per segment,
  so `u = 1.0` is the end of the first segment and `u = max_u(curve)` is the end of the curve.

  ## Examples
      iex> Curves.max_u(Curves.define_bezier(:ease_in))
      1.0
      iex> Curves.max_u(Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}]))
      3.0
      iex> Curves.max_u(Curves.define_polyline([{0, 0}, {1, 1}, {2, 0}]))
      2.0
  """
  @spec max_u(Bezier.t() | Spline.t() | Polyline.t()) :: float()
  def max_u(%Bezier{}), do: 1.0
  def max_u(%Spline{max_u: max_u}), do: max_u
  def max_u(%Polyline{max_u: max_u}), do: max_u

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
  @spec take(Bezier.t() | Spline.t() | Polyline.t(), n :: pos_integer(), T.opts()) ::
          {:ok, T.point_list()} | {:error, term()}
  def take(curve, n, opts \\ [])
  def take(_curve, n, _opts) when not is_integer(n) or n < 1, do: raise_bad_count(n)

  def take(curve, n, opts) do
    cond do
      is_struct(curve, Bezier) -> Bezier.take(curve, n, opts)
      is_struct(curve, Spline) -> Spline.take(curve, n, opts)
      is_struct(curve, Polyline) -> Polyline.take(curve, n, opts)
      true -> Errors.raise_not_a_curve(curve)
    end
  end

  @doc ~s"""
  The raising version of `take/3`: returns the list of points, or raises one of the `Curves.Exceptions` errors.

  ## Examples
      iex> Curves.take!(Curves.define_bezier([{0, 0}, {1, 2}, {2, 0}]), 2)
      [{1.0, 1.0}, {2.0, 0.0}]
  """
  @spec take!(Bezier.t() | Spline.t() | Polyline.t(), n :: pos_integer(), T.opts()) ::
          T.point_list()
  def take!(curve, n, opts \\ [])
  def take!(_curve, n, _opts) when not is_integer(n) or n < 1, do: raise_bad_count(n)

  def take!(curve, n, opts) do
    cond do
      is_struct(curve, Bezier) -> Bezier.take!(curve, n, opts)
      is_struct(curve, Spline) -> Spline.take!(curve, n, opts)
      is_struct(curve, Polyline) -> Polyline.take!(curve, n, opts)
      true -> Errors.raise_not_a_curve(curve)
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
