defmodule Curves.Transform do
  alias Curves.Utils.Types, as: T
  alias Curves.Transform.{Move, Scale}
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Spline.Curve, as: Spline

  @doc false
  def apply_all_transformations(curve) do
    Enum.reduce(curve.transformations, curve, fn {mod, func, args, _prev}, curve -> apply(mod, func, [curve | args]) end)
      |> apply_origin_offset()
      |> apply_scale()
  end

  defp apply_origin_offset(%Bezier{points: points, origin: origin} = curve) do
    points = Nx.add(points, origin)
    Map.put(curve, :points, points)
  end
  defp apply_origin_offset(%Spline{segments: segments, origin: origin} = curve) do
    segments = Nx.add(segments, origin)
    Map.put(curve, :segments, segments)
  end

  defp apply_scale(%Bezier{points: points, scale: scale, origin: _origin} = curve) do
    points = Nx.multiply(points, Nx.tensor([ [scale] ]))
    Map.put(curve, :points, points)
  end
  defp apply_scale(%Spline{segments: segments, scale: scale, origin: _origin} = curve) do
    segments = Nx.multiply(segments, Nx.tensor([ [ [scale] ] ]))
    Map.put(curve, :segments, segments)
  end


  # Put a new transformation in the :transformations list, then recompress.
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
  resize the entire curve. Default scale is 1.0. To double the curve, use 2.0. To shrink it by half, use 0.5.
  """
  @spec set_scale(curve :: T.curve_struct(), scale :: number()) :: T.curve_struct()
  def set_scale(curve, scale), do: add(curve, {Scale, :set_scale, [scale], curve.scale})
end
