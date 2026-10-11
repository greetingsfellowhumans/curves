defmodule Curves.Transform do
  @moduledoc ~s"""
  Utility functions that allow you to resize, move, and rotate a curve.

  The curve is first scaled and then rotated around its own `{0, 0}`, and finally moved to its
  position (the `:origin` option, `set_position/2` and the like). This is the usual
  scale-rotate-translate order (like SVG's `transform="translate(…) rotate(…) scale(…)"`), so
  scaling or rotating a curve never moves it away from its position.

  Positions are `{x, y}` tuples of numbers, and amounts are numbers.
  Anything else raises an `ArgumentError`.
  """
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Polyline.Curve, as: Polyline
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Transform.{Move, Rotate, Scale}
  alias Curves.Types, as: T
  alias Curves.Utils.Errors
  alias Curves.Utils.Vec

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

  # Applies `fun` to every point of every segment.
  @spec map_segment_points(list(list(T.point_tuple())), (T.point_tuple() -> T.point_tuple())) ::
          list(list(T.point_tuple()))
  defp map_segment_points(segments, fun), do: Enum.map(segments, &Enum.map(&1, fun))

  # Returns a new copy of `points` scaled, then rotated, then moved by the origin,
  # the same way the curve's own points are. `curve` must already have been through
  # apply_all_transformations/1. The curve itself is not changed, so a spline's
  # original `:points` stay as the user gave them.
  @doc false
  @spec transform_points(curve :: T.curve_data(), points :: T.point_list()) :: T.point_list()
  def transform_points(%{origin: origin, scale: scale} = curve, points) do
    Enum.map(points, fn point -> point |> Vec.scale(scale) |> rotate(curve) |> Vec.add(origin) end)
  end

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
  @spec add(T.curve_struct(), {module(), atom(), list()}, atom()) :: T.curve_struct()
  defp add(curve, transformation, field) do
    cond do
      is_struct(curve, Bezier) -> Bezier.add_transformation(curve, transformation, field)
      is_struct(curve, Spline) -> Spline.add_transformation(curve, transformation, field)
      is_struct(curve, Polyline) -> Polyline.add_transformation(curve, transformation, field)
      true -> Errors.raise_not_a_curve(curve)
    end
  end

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
  @spec set_position(curve :: T.curve_struct(), T.point_tuple()) :: T.curve_struct()
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
  @spec inc_position(curve :: T.curve_struct(), T.point_tuple()) :: T.curve_struct()
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
  @spec inc_x(curve :: T.curve_struct(), xinc :: T.coord()) :: T.curve_struct()
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
  @spec inc_y(curve :: T.curve_struct(), yinc :: T.coord()) :: T.curve_struct()
  def inc_y(curve, yinc) when is_number(yinc), do: add(curve, {Move, :inc_y, [yinc]}, :origin)

  def inc_y(_curve, yinc), do: raise_not_a_number("inc_y/2", yinc)

  @doc ~s"""
  resize the entire curve ignoring the existing scale. Default scale is 1.0. To double the curve, use 2.0. To shrink it by half, use 0.5.

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      0.5
      iex> y
      0.5
      iex> curve = Transform.set_scale(curve, 10.0)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      5.0
      iex> y
      5.0

  The curve is scaled around its own `{0, 0}`, so a moved curve stays where it was put:

      iex> curve = Curves.define_bezier([{0, 0}, {4, 0}]) |> Transform.set_position({10, 10})
      iex> curve = Transform.set_scale(curve, 2)
      iex> Curves.solve!(curve, 0.0)
      {10.0, 10.0}
      iex> Curves.solve!(curve, 1.0)
      {18.0, 10.0}
  """
  @spec set_scale(curve :: T.curve_struct(), scale :: number()) :: T.curve_struct()
  def set_scale(curve, scale) when is_number(scale),
    do: add(curve, {Scale, :set_scale, [scale]}, :scale)

  def set_scale(_curve, scale), do: raise_not_a_number("set_scale/2", scale)

  @doc ~s"""
  resize the entire curve, adding to the existing scale.

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      0.5
      iex> y
      0.5
      iex> curve = Transform.inc_scale(curve, 10.0)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      5.5
      iex> y
      5.5
  """
  @spec inc_scale(curve :: T.curve_struct(), amount :: number()) :: T.curve_struct()
  def inc_scale(curve, amount) when is_number(amount),
    do: add(curve, {Scale, :inc_scale, [amount]}, :scale)

  def inc_scale(_curve, amount), do: raise_not_a_number("inc_scale/2", amount)

  @doc ~s"""
  increase rotation (counter-clockwise) by the given amount.

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> x
      0.5
      iex> y
      0.5
      iex> curve = Transform.inc_rotation(curve, 45.0)
      iex> {x, y} = Curves.solve!(curve, 0.5)
      iex> Float.round(x, 5)
      0.0
      iex> Float.round(y, 5)
      0.70711
  """
  @spec inc_rotation(curve :: T.curve_struct(), number()) :: T.curve_struct()
  def inc_rotation(curve, amount) when is_number(amount),
    do: add(curve, {Rotate, :inc_rotation, [amount]}, :rotation)

  def inc_rotation(_curve, amount), do: raise_not_a_number("inc_rotation/2", amount)

  @doc ~s"""
  Rotate the curve counter-clockwise, in degrees, around its position (the `:origin` option or
  `set_position/2`, `{0.0, 0.0}` by default).

  ## Examples
      iex> curve = Curves.define_bezier(:linear_up_right)
      iex> {x, y} = Curves.solve!(curve, 1.0)
      iex> x
      1.0
      iex> y
      1.0
      iex> curve = Transform.set_rotation(curve, 90)
      iex> {x, y} = Curves.solve!(curve, 1.0)
      iex> Float.round(x, 5)
      -1.0
      iex> Float.round(y, 5)
      1.0
  """
  @spec set_rotation(curve :: T.curve_struct(), number()) :: T.curve_struct()
  def set_rotation(curve, amount) when is_number(amount),
    do: add(curve, {Rotate, :set_rotation, [amount]}, :rotation)

  def set_rotation(_curve, amount), do: raise_not_a_number("set_rotation/2", amount)
end
