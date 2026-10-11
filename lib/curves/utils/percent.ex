defmodule Curves.Utils.Percent do
  @moduledoc false
  # Turns solved points into percentages of a curve's bounding box,
  # for the `:force_percent` option.

  alias Curves.TensorTypes, as: TensorT
  alias Curves.Types, as: T

  # Anything with min/max bounds, such as a Bezier or Spline curve.
  @type bounded :: %{xmin: T.coord(), xmax: T.coord(), ymin: T.coord(), ymax: T.coord()}

  # Finds the lowest and highest x and y in a `{dimension, point}` tensor.
  # Example: points (0, 5) and (10, 1) give xmin 0.0, xmax 10.0, ymin 1.0, ymax 5.0.
  # Rotating a curve adds tiny float noise, so a flat axis can come back
  # very slightly not flat (e.g. -1.0 and -1.0000001). That is left as-is.
  @spec get_bounds(points :: TensorT.points()) :: bounded()
  def get_bounds(points) when is_list(points), do: Curves.Utils.Vec.bounds(points)

  def get_bounds(points) do
    %{
      xmin: Nx.reduce_min(points[dimension: 0]) |> Nx.to_number(),
      xmax: Nx.reduce_max(points[dimension: 0]) |> Nx.to_number(),
      ymin: Nx.reduce_min(points[dimension: 1]) |> Nx.to_number(),
      ymax: Nx.reduce_max(points[dimension: 1]) |> Nx.to_number()
    }
  end

  # The curve's lowest and highest x and y after transforms.
  # `curve` must already have been through Curves.Transform.apply_all_transformations/1.
  # `get_points` returns the transformed points, and is only called when needed:
  # an untransformed curve (scale 1, rotation 0, origin {0, 0}) reuses the bounds stored at
  # define time. They are exactly what transforming would give, and skipping it keeps define fast.
  @spec get_bounds_after_transforms(T.curve_struct(), (-> TensorT.points())) :: bounded()
  def get_bounds_after_transforms(%{scale: scale, rotation: rotation} = curve, get_points)
      when scale == 1 and rotation == 0,
      do: get_bounds_at_origin(curve.origin, curve, get_points)

  def get_bounds_after_transforms(_curve, get_points), do: get_bounds(get_points.())

  # Stored bounds when the origin is {0, 0}, otherwise the bounds of the transformed points.
  @spec get_bounds_at_origin(list(number()), T.curve_struct(), (-> TensorT.points())) :: bounded()
  defp get_bounds_at_origin({x, y}, curve, _get_points) when x == 0 and y == 0,
    do: Map.take(curve, [:xmin, :xmax, :ymin, :ymax])

  defp get_bounds_at_origin(_origin, _curve, get_points), do: get_bounds(get_points.())

  # Normalizes the point only when `:force_percent` is set in opts.
  # Any truthy value counts as "on", not just `true`.
  @spec maybe_normalize(bounded(), T.point_tuple(), T.opts()) :: T.point_tuple()
  def maybe_normalize(curve, point, opts),
    do: normalize_when(Keyword.get(opts, :force_percent), curve, point)

  # Maps each coordinate from its min..max range to 0.0..1.0.
  # Example: x = 5.0 with xmin = 0.0 and xmax = 10.0 becomes 0.5.
  @spec normalize(bounded(), T.point_tuple()) :: T.point_tuple()
  def normalize(curve, {x, y}),
    do: {scale(x, curve.xmin, curve.xmax), scale(y, curve.ymin, curve.ymax)}

  # Off when the flag is false or missing, otherwise on.
  @spec normalize_when(term(), bounded(), T.point_tuple()) :: T.point_tuple()
  defp normalize_when(flag, _curve, point) when flag in [false, nil], do: point
  defp normalize_when(_flag, curve, point), do: normalize(curve, point)

  # Where `coord` sits between `min` and `max`, as a fraction.
  # A flat range (min == max) would divide by zero, so it returns 0.5: the middle of 0..1,
  # which is where a horizontal or vertical line naturally sits.
  @spec scale(float(), T.coord(), T.coord()) :: float()
  defp scale(coord, min, max) when is_float(coord) and min == max, do: 0.5
  defp scale(coord, min, max) when is_float(coord), do: (coord - min) / (max - min)
end
