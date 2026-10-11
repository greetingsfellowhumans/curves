defmodule Curves.Transform do
  @moduledoc ~s"""
  Utility functions that allow you to resize, move, and rotate a curve.
  """
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Spline.Curve, as: Spline
  alias Curves.TensorTypes, as: TensorT
  alias Curves.Transform.{Move, Rotate, Scale}
  alias Curves.Types, as: T
  alias Curves.Utils.Vec

  # Replays the transformations list, then moves, scales and rotates a copy of the points
  # (beziers) or segments (splines). Used by compress; the stored curve keeps its original points.
  @doc false
  @spec apply_all_transformations(T.curve_struct()) :: T.curve_struct()
  def apply_all_transformations(curve) do
    Enum.reduce(curve.transformations, curve, fn {mod, func, args, _prev}, curve ->
      apply(mod, func, [curve | args])
    end)
    |> apply_origin_offset()
    |> apply_scale()
    |> apply_rotation()
  end

  @spec apply_origin_offset(T.curve_struct()) :: T.curve_struct()
  defp apply_origin_offset(%Bezier{points: points, origin: origin} = curve),
    do: %{curve | points: Enum.map(points, &Vec.add(&1, origin))}

  defp apply_origin_offset(%Spline{segments: segments} = curve) do
    segments = Nx.add(segments, origin_tensor(curve))
    Map.put(curve, :segments, segments)
  end

  @spec apply_scale(T.curve_struct()) :: T.curve_struct()
  defp apply_scale(%Bezier{points: points, scale: scale} = curve),
    do: %{curve | points: Enum.map(points, &Vec.scale(&1, scale))}

  defp apply_scale(%Spline{segments: segments, scale: scale, origin: _origin} = curve) do
    segments = Nx.multiply(segments, Nx.tensor([[[scale]]]))
    Map.put(curve, :segments, segments)
  end

  @doc false
  # Rotating by 0 changes nothing, so skip the Nx work. `==` matches both 0 and 0.0 (new curves start at 0.0).
  @spec apply_rotation(T.curve_struct()) :: T.curve_struct()
  def apply_rotation(%{rotation: rotation} = curve) when rotation == 0, do: curve

  def apply_rotation(%Bezier{points: points, rotation: angle, origin: origin} = curve),
    do: %{curve | points: Enum.map(points, &Vec.rotate(&1, angle, origin))}

  def apply_rotation(%Spline{segments: segments, rotation: angle} = curve) do
    segments = Rotate.rotate_points(segments, angle, origin_tensor(curve))
    Map.put(curve, :segments, segments)
  end

  # Returns a new copy of `points` moved by the origin, then scaled, then rotated,
  # the same way the curve's own points are. `curve` must already have been through
  # apply_all_transformations/1. The curve itself is not changed, so a spline's
  # original `:points` stay as the user gave them.
  @doc false
  @spec transform_points(curve :: T.curve_struct(), points :: TensorT.points()) ::
          TensorT.points()
  def transform_points(%{scale: scale} = curve, points) do
    points
    |> Nx.add(origin_tensor(curve))
    |> Nx.multiply(Nx.tensor([[scale]]))
    |> rotate_points(curve)
  end

  # Matches apply_rotation/1: a rotation of 0 or 0.0 is skipped.
  @spec rotate_points(points :: TensorT.points(), curve :: T.curve_struct()) :: TensorT.points()
  defp rotate_points(points, %{rotation: rotation}) when rotation == 0, do: points

  defp rotate_points(points, %{rotation: angle} = curve),
    do: Rotate.rotate_points(points, angle, origin_tensor(curve))

  # Splines still store points as Nx tensors (until they move to plain floats too),
  # so their tuple origin is turned into a {2, 1} tensor of the curve's float type.
  @spec origin_tensor(Spline.t()) :: Nx.Tensor.t()
  defp origin_tensor(%Spline{origin: origin, opts: opts}),
    do: Curves.Utils.Point.new_point(origin, opts)

  # Put a new transformation in the :transformations list, then recompress.
  @spec add(T.curve_struct(), {module(), atom(), list(), term()}) :: T.curve_struct()
  defp add(%Bezier{} = curve, transformation) do
    curve = Map.update!(curve, :transformations, &(&1 ++ [transformation]))
    {:ok, cb} = Bezier.compress(curve)
    Map.put(curve, :compressed, cb)
  end

  defp add(%Spline{} = curve, transformation) do
    curve = Map.update!(curve, :transformations, &(&1 ++ [transformation]))
    {:ok, cb} = Spline.compress(curve)
    Map.put(curve, :compressed, cb)
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
  def set_position(curve, origin), do: add(curve, {Move, :set_position, [origin], curve.origin})

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
  def inc_position(curve, pos), do: add(curve, {Move, :inc_position, [pos], curve.origin})

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
  def inc_x(curve, xinc), do: add(curve, {Move, :inc_x, [xinc], curve.origin})

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
  def inc_y(curve, yinc), do: add(curve, {Move, :inc_y, [yinc], curve.origin})

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
  """
  @spec set_scale(curve :: T.curve_struct(), scale :: number()) :: T.curve_struct()
  def set_scale(curve, scale), do: add(curve, {Scale, :set_scale, [scale], curve.scale})

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
  def inc_scale(curve, amount), do: add(curve, {Scale, :inc_scale, [amount], curve.scale})

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
  def inc_rotation(curve, amount),
    do: add(curve, {Rotate, :inc_rotation, [amount], curve.rotation})

  @doc ~s"""
  Rotate the curve counter-clockwise around the origin (Origin defaults to {0.0, 0.0}).

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
  def set_rotation(curve, amount),
    do: add(curve, {Rotate, :set_rotation, [amount], curve.rotation})
end
