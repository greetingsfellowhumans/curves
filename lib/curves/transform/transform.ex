defmodule Curves.Transform do
  @moduledoc ~s"""
  Utility functions that allow you to move, resize, stretch, flip, rotate and reverse a curve,
  without changing the points you defined it with.

  | To... | Use |
  | --- | --- |
  | move it | `set_position/2`, `inc_position/2`, `inc_x/2`, `inc_y/2` |
  | resize or stretch it | `set_scale/3`, `inc_scale/3` (a number, or `{x, y}` for each direction) |
  | mirror it | `flip_x/2`, `flip_y/2` |
  | rotate it | `set_rotation/3`, `inc_rotation/3` (degrees, counter-clockwise) |
  | travel it the other way | `reverse/1` |

  The curve is first scaled and then rotated around its own `{0, 0}`, and finally moved to its
  position (the `:origin` option, `set_position/2` and the like). This is the usual
  scale-rotate-translate order (like SVG's `transform="translate(…) rotate(…) scale(…)"`), so
  scaling or rotating a curve never moves it away from its position. To scale, flip or rotate around
  some other point, such as the curve's middle, pass `around: :center` or `around: {x, y}`.

  Positions are `{x, y}` tuples of numbers, and amounts are numbers.
  Anything else raises an `ArgumentError`.

  ## Drawings

  Every function here also takes a `Curves.Drawing` (from `Curves.from_svg/2`), or a group or shape
  in one, and changes it as a whole, the same way it changes a curve. Everything in it moves
  together, text and other kept markup too. `around: :center` is the middle of its shapes: text and
  other markup can't be measured, so they don't count.
  `Curves.Drawing.update/3` and `update_in/3` change one part, found by its `id`:

  ```elixir
  drawing
  |> Curves.Transform.set_scale(2)
  |> Curves.Drawing.update("wheel", &Curves.Transform.inc_rotation(&1, 45, around: :center))
  ```

  The change is kept on the drawing, group or shape (in its `:origin`, `:scale` and `:rotation`),
  so it can be set again later, like a curve's. `Curves.Drawing.shapes/1` and `curves/1` give the
  curves where they end up, and `Curves.Svg` draws it there. A `Curves.Drawing.Subpath` changes its
  curve.
  """
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Node, Shape, Subpath}
  alias Curves.Polyline.Curve, as: Polyline
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Transform.{Move, Rotate, Scale}
  alias Curves.Types, as: T
  alias Curves.Utils.{Errors, Segment, Vec}

  # A scale is a number, or an {x, y} pair to scale the two directions separately.
  defguardp is_scale(s)
            when is_number(s) or
                   (is_tuple(s) and tuple_size(s) == 2 and is_number(elem(s, 0)) and
                      is_number(elem(s, 1)))

  @typedoc ~s"""
  Anything these functions change: a curve, or a `Curves.Drawing`, or a group, shape or subpath
  in one. A drawing, group or shape changes as a whole (everything in it, text too); a subpath
  changes its curve.
  """
  @type transformable() ::
          T.curve_struct() | Drawing.t() | Group.t() | Shape.t() | Subpath.t()

  @typedoc ~s"""
  The point to scale, flip or rotate around: `:center` (the middle of the curve's points) or an
  `{x, y}` point, in the curve's own coordinates. `nil` (the default) is the curve's own `{0, 0}`.
  """
  @type around() :: nil | :center | T.point_tuple()

  # Replays the transformations list, then scales, rotates and moves a copy of the points
  # (beziers) or segments (splines). Used by compress; the stored curve keeps its original points.
  @doc false
  @spec apply_all_transformations(T.curve_data()) :: T.curve_data()
  def apply_all_transformations(curve) do
    Enum.reduce(curve.transformations, curve, fn {mod, func, args, _prev}, curve ->
      apply(mod, func, [curve | args])
    end)
    |> apply_scale()
    |> apply_rotation()
    |> apply_origin_offset()
  end

  @spec apply_origin_offset(T.curve_data()) :: T.curve_data()
  defp apply_origin_offset(%Bezier{points: points, origin: origin} = curve),
    do: %{curve | points: Enum.map(points, &Vec.add(&1, origin))}

  defp apply_origin_offset(%Polyline{points: points, origin: origin} = curve),
    do: %{curve | points: Enum.map(points, &Vec.add(&1, origin))}

  defp apply_origin_offset(%Spline{segments: segments, origin: origin} = curve),
    do: %{curve | segments: map_segment_points(segments, &Vec.add(&1, origin))}

  @spec apply_scale(T.curve_data()) :: T.curve_data()
  defp apply_scale(%Bezier{points: points, scale: scale} = curve),
    do: %{curve | points: Enum.map(points, &Vec.scale(&1, scale))}

  defp apply_scale(%Polyline{points: points, scale: scale} = curve),
    do: %{curve | points: Enum.map(points, &Vec.scale(&1, scale))}

  defp apply_scale(%Spline{segments: segments, scale: scale} = curve),
    do: %{curve | segments: map_segment_points(segments, &Vec.scale(&1, scale))}

  @doc false
  # Rotates around {0, 0}, before the curve is moved to its position, so it turns around that position.
  # Rotating by 0 changes nothing, so skip it. `==` matches both 0 and 0.0 (new curves start at 0.0).
  @spec apply_rotation(T.curve_data()) :: T.curve_data()
  def apply_rotation(%{rotation: rotation} = curve) when rotation == 0, do: curve

  def apply_rotation(%Bezier{points: points, rotation: angle} = curve),
    do: %{curve | points: Enum.map(points, &Vec.rotate(&1, angle, {0.0, 0.0}))}

  def apply_rotation(%Polyline{points: points, rotation: angle} = curve),
    do: %{curve | points: Enum.map(points, &Vec.rotate(&1, angle, {0.0, 0.0}))}

  def apply_rotation(%Spline{segments: segments, rotation: angle} = curve),
    do: %{curve | segments: map_segment_points(segments, &Vec.rotate(&1, angle, {0.0, 0.0}))}

  # Applies `fun` to every point of every segment. An arc's points are its centre and axis ends,
  # which moves the arc exactly (see Curves.Utils.Arc).
  @spec map_segment_points(list(Segment.t()), (T.point_tuple() -> T.point_tuple())) ::
          list(Segment.t())
  defp map_segment_points(segments, fun), do: Enum.map(segments, &Segment.map_points(&1, fun))

  # Returns a new copy of `points` scaled, then rotated, then moved by the origin,
  # the same way the curve's own points are. `curve` must already have been through
  # apply_all_transformations/1. The curve itself is not changed, so a spline's
  # original `:points` stay as the user gave them.
  @doc false
  @spec transform_points(curve :: T.curve_data(), points :: T.point_list()) :: T.point_list()
  def transform_points(%{origin: origin, scale: scale} = curve, points) do
    Enum.map(points, fn point -> point |> Vec.scale(scale) |> rotate(curve) |> Vec.add(origin) end)
  end

  # One point, transformed like transform_points/2.
  @doc false
  @spec transform_points_one(T.point_tuple(), T.curve_data()) :: T.point_tuple()
  def transform_points_one(point, curve), do: hd(transform_points(curve, [point]))

  # Matches apply_rotation/1: around {0, 0}, and a rotation of 0 or 0.0 is skipped.
  @spec rotate(T.point_tuple(), T.curve_data()) :: T.point_tuple()
  defp rotate(point, %{rotation: rotation}) when rotation == 0, do: point
  defp rotate(point, %{rotation: angle}), do: Vec.rotate(point, angle, {0.0, 0.0})

  # The amount given to inc_x/2, set_scale/2 and the like must be a number. Checked up front,
  # because otherwise it would only fail later, deep inside the maths that redraws the curve.
  @spec raise_not_a_number(String.t(), term()) :: no_return()
  defp raise_not_a_number(function, value) do
    raise ArgumentError, "Curves.Transform.#{function} needs a number, got: #{inspect(value)}"
  end

  # Hands the transformation to the curve's own module, which adds it and recompresses.
  # `field` names the value the transformation changes (e.g. :origin). Only Bezier and
  # Spline may touch their (opaque) fields, so that work lives there, not here.
  @spec add(transformable(), {module(), atom(), list()}, atom()) :: transformable()
  defp add(curve, transformation, field) do
    cond do
      is_struct(curve, Bezier) -> Bezier.add_transformation(curve, transformation, field)
      is_struct(curve, Spline) -> Spline.add_transformation(curve, transformation, field)
      is_struct(curve, Polyline) -> Polyline.add_transformation(curve, transformation, field)
      drawing_node?(curve) -> Node.transform(curve, transformation)
      is_struct(curve, Subpath) -> %{curve | curve: add(curve.curve, transformation, field)}
      true -> Errors.raise_not_a_curve(curve)
    end
  end

  # A whole drawing, group or shape: it keeps its own move, scale and rotation (see
  # Curves.Drawing.Node).
  @spec drawing_node?(term()) :: boolean()
  defp drawing_node?(term),
    do: is_struct(term, Drawing) or is_struct(term, Group) or is_struct(term, Shape)

  @doc ~s"""
  Ignore current position and set a new one.

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> {x, _y} = Curves.solve!(curve, 0.5)
      iex> x
      0.5
      iex> curve = Curves.Transform.set_position(curve, {10, 10})
      iex> {x, _y} = Curves.solve!(curve, 0.5)
      iex> x
      10.5
  """
  @spec set_position(curve :: transformable(), T.point_tuple()) :: transformable()
  def set_position(curve, origin), do: add(curve, {Move, :set_position, [origin]}, :origin)

  @doc ~s"""
  Using the current position increase both the x and y coordinates.
  It is also possible to decrease by passing a negative number

  ## Examples
      iex> curve = Curves.define_bezier(:linear, origin: {10, 10})
      iex> {x, _y} = Curves.solve!(curve, 0.5)
      iex> x
      10.5
      iex> curve = Transform.inc_position(curve, {10, 10})
      iex> {x, _y} = Curves.solve!(curve, 0.5)
      iex> x
      20.5
  """
  @spec inc_position(curve :: transformable(), T.point_tuple()) :: transformable()
  def inc_position(curve, pos), do: add(curve, {Move, :inc_position, [pos]}, :origin)

  @doc ~s"""
  Using the current position increase the x coordinates.
  It is also possible to decrease by passing a negative number

  ## Examples
      iex> curve = Curves.define_bezier(:linear, origin: {10, 10})
      iex> {x, _y} = Curves.solve!(curve, 0.5)
      iex> x
      10.5
      iex> curve = Transform.inc_x(curve, 10)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      20.5
      iex> y
      10.5
  """
  @spec inc_x(curve :: transformable(), xinc :: T.coord()) :: transformable()
  def inc_x(curve, xinc) when is_number(xinc), do: add(curve, {Move, :inc_x, [xinc]}, :origin)

  def inc_x(_curve, xinc), do: raise_not_a_number("inc_x/2", xinc)

  @doc ~s"""
  Using the current position increase the y coordinates.
  It is also possible to decrease by passing a negative number

  ## Examples
      iex> curve = Curves.define_bezier(:linear, origin: {10, 10})
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      10.5
      iex> y
      10.5
      iex> curve = Transform.inc_y(curve, -10)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      10.5
      iex> y
      0.5
  """
  @spec inc_y(curve :: transformable(), yinc :: T.coord()) :: transformable()
  def inc_y(curve, yinc) when is_number(yinc), do: add(curve, {Move, :inc_y, [yinc]}, :origin)

  def inc_y(_curve, yinc), do: raise_not_a_number("inc_y/2", yinc)

  # The `around:` option shared by the scale, rotation and flip functions.
  @around_doc """
  The curve is scaled and rotated around its own `{0, 0}`. Pass `around:` to turn around a
  different point instead, which then stays exactly where it is: either `:center` (the middle of the
  curve's points) or an `{x, y}` point. Both are in the curve's own coordinates: the points you defined
  it with, before any transforms.

  `around:` keeps that point still by moving the curve's position, and the move stays: setting the
  rotation back to `0` (or the scale back to `1`) later, without `around:`, leaves the curve moved.
  """

  @doc ~s"""
  Resize the curve, replacing the existing scale. The default scale is `1.0`: `2.0` doubles the curve and
  `0.5` halves it. A negative scale flips it.

  Give an `{x, y}` pair to scale the two directions separately, e.g. `{2, 0.5}` makes it twice as wide
  and half as tall.

  #{@around_doc}

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> Curves.solve!(curve, 0.5)
      {0.5, 0.5}
      iex> curve = Transform.set_scale(curve, 10.0)
      iex> Curves.solve!(curve, 0.5)
      {5.0, 5.0}

  Separate x and y scales:

      iex> curve = Curves.define_bezier([{0, 0}, {2, 2}]) |> Transform.set_scale({2, 0.5})
      iex> Curves.solve!(curve, 1.0)
      {4.0, 1.0}

  The curve is scaled around its own `{0, 0}`, so a moved curve stays where it was put:

      iex> curve = Curves.define_bezier([{0, 0}, {4, 0}]) |> Transform.set_position({10, 10})
      iex> curve = Transform.set_scale(curve, 2)
      iex> Curves.solve!(curve, 0.0)
      {10.0, 10.0}
      iex> Curves.solve!(curve, 1.0)
      {18.0, 10.0}

  Scaled around its middle instead, it grows equally in every direction:

      iex> curve = Curves.define_bezier([{0, 0}, {2, 2}]) |> Transform.set_scale(2, around: :center)
      iex> {Curves.solve!(curve, 0.0), Curves.solve!(curve, 1.0)}
      {{-1.0, -1.0}, {3.0, 3.0}}
  """
  @spec set_scale(
          transformable(),
          scale :: number() | {number(), number()},
          opts :: [around: around()]
        ) ::
          transformable()
  def set_scale(curve, scale, opts \\ [])

  def set_scale(curve, scale, opts) when is_scale(scale),
    do: add(curve, {Scale, :set_scale, [scale, around!(opts)]}, :scale)

  def set_scale(_curve, scale, _opts), do: raise_not_a_scale("set_scale/3", scale)

  @doc ~s"""
  Resize the curve, adding to the existing scale. With an `{x, y}` pair, each direction is added to
  separately; a single number adds to both. A flipped direction has a negative scale, so adding to
  it brings it towards `0`, making the curve smaller that way.

  #{@around_doc}

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> curve = Transform.inc_scale(curve, 10.0)
      iex> Curves.solve!(curve, 0.5)
      {5.5, 5.5}
      iex> curve = Transform.inc_scale(curve, {0, -10})
      iex> Curves.solve!(curve, 0.5)
      {5.5, 0.5}
  """
  @spec inc_scale(
          transformable(),
          amount :: number() | {number(), number()},
          opts :: [around: around()]
        ) ::
          transformable()
  def inc_scale(curve, amount, opts \\ [])

  def inc_scale(curve, amount, opts) when is_scale(amount),
    do: add(curve, {Scale, :inc_scale, [amount, around!(opts)]}, :scale)

  def inc_scale(_curve, amount, _opts), do: raise_not_a_scale("inc_scale/3", amount)

  @doc ~s"""
  Mirror the curve left to right (its x scale turns negative, or back again).

  #{@around_doc}

  ## Examples
      iex> curve = Curves.define_bezier([{1, 0}, {3, 2}])
      iex> Curves.solve!(Transform.flip_x(curve), 1.0)
      {-3.0, 2.0}
      iex> Curves.solve!(Transform.flip_x(curve, around: :center), 1.0)
      {1.0, 2.0}
  """
  @spec flip_x(transformable(), opts :: [around: around()]) :: transformable()
  def flip_x(curve, opts \\ []), do: add(curve, {Scale, :flip, [:x, around!(opts)]}, :scale)

  @doc ~s"""
  Mirror the curve top to bottom (its y scale turns negative, or back again).

  #{@around_doc}

  ## Examples
      iex> curve = Curves.define_bezier([{1, 0}, {3, 2}])
      iex> Curves.solve!(Transform.flip_y(curve), 1.0)
      {3.0, -2.0}
      iex> Curves.solve!(Transform.flip_y(curve, around: :center), 1.0)
      {3.0, 0.0}
  """
  @spec flip_y(transformable(), opts :: [around: around()]) :: transformable()
  def flip_y(curve, opts \\ []), do: add(curve, {Scale, :flip, [:y, around!(opts)]}, :scale)

  @doc ~s"""
  Increase the rotation (counter-clockwise) by the given amount, in degrees.

  #{@around_doc}

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> curve = Transform.inc_rotation(curve, 45.0)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> {Float.round(x, 5), Float.round(y, 5)}
      {0.0, 0.70711}
  """
  @spec inc_rotation(transformable(), number(), opts :: [around: around()]) :: transformable()
  def inc_rotation(curve, amount, opts \\ [])

  def inc_rotation(curve, amount, opts) when is_number(amount),
    do: add(curve, {Rotate, :inc_rotation, [amount, around!(opts)]}, :rotation)

  def inc_rotation(_curve, amount, _opts), do: raise_not_a_number("inc_rotation/3", amount)

  @doc ~s"""
  Rotate the curve counter-clockwise, in degrees, replacing the existing rotation. It turns around its
  position (the `:origin` option or `set_position/2`, `{0.0, 0.0}` by default).

  #{@around_doc}

  ## Examples
      iex> curve = Curves.define_bezier(:linear_up_right)
      iex> curve = Transform.set_rotation(curve, 90)
      iex> {x, y} = Curves.solve!(curve, 1.0)
      iex> {Float.round(x, 5), Float.round(y, 5)}
      {-1.0, 1.0}

  Turned around its middle, the line stays centred on the same spot:

      iex> curve = Curves.define_bezier([{0, 0}, {2, 0}]) |> Transform.set_rotation(90, around: :center)
      iex> for t <- [0.0, 1.0], {x, y} = Curves.solve!(curve, t), do: {Float.round(x, 5), Float.round(y, 5)}
      [{1.0, -1.0}, {1.0, 1.0}]
  """
  @spec set_rotation(transformable(), number(), opts :: [around: around()]) :: transformable()
  def set_rotation(curve, amount, opts \\ [])

  def set_rotation(curve, amount, opts) when is_number(amount),
    do: add(curve, {Rotate, :set_rotation, [amount, around!(opts)]}, :rotation)

  def set_rotation(_curve, amount, _opts), do: raise_not_a_number("set_rotation/3", amount)

  @doc ~s"""
  The same curve, travelled the other way: `t` (or `u`) `= 0.0` is now its old end. Its shape,
  position and transforms don't change. Handy to play an easing backwards, or follow a path in reverse.

  ## Examples
      iex> curve = Curves.define_bezier([{0, 0}, {1, 2}])
      iex> Curves.solve!(Transform.reverse(curve), 0.0)
      {1.0, 2.0}
      iex> spline = Curves.define_catmull_rom([{0, 0}, {1, 1}, {2, 0}])
      iex> Curves.solve!(Transform.reverse(spline), 2.0)
      {0.0, 0.0}
  """
  @spec reverse(transformable()) :: transformable()
  def reverse(curve) do
    cond do
      is_struct(curve, Bezier) -> Bezier.reverse(curve)
      is_struct(curve, Spline) -> Spline.reverse(curve)
      is_struct(curve, Polyline) -> Polyline.reverse(curve)
      drawing_node?(curve) -> Curves.Drawing.update_curves(curve, &reverse/1)
      is_struct(curve, Subpath) -> %{curve | curve: reverse(curve.curve)}
      true -> Errors.raise_not_a_curve(curve)
    end
  end

  # The :around option, checked: nil, :center or an {x, y} point.
  @spec around!(keyword()) :: around()
  defp around!(opts) when is_list(opts), do: opts |> Keyword.get(:around) |> check_around()

  defp around!(opts),
    do:
      raise(
        ArgumentError,
        "expected a keyword list of options, like [around: :center], got: #{inspect(opts)}"
      )

  @spec check_around(term()) :: around()
  defp check_around(around) when around in [nil, :center], do: around
  defp check_around({x, y} = around) when is_number(x) and is_number(y), do: around

  defp check_around(other) do
    raise ArgumentError,
          ":around must be :center or an {x, y} point in the curve's own coordinates, got: #{inspect(other)}"
  end

  # A scale must be a number or an {x, y} pair of numbers.
  @spec raise_not_a_scale(String.t(), term()) :: no_return()
  defp raise_not_a_scale(function, value) do
    raise ArgumentError,
          "Curves.Transform.#{function} needs a number or an {x, y} pair of numbers, got: #{inspect(value)}"
  end
end
