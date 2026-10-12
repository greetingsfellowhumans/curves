defmodule Curves.Transform.Pivot do
  @moduledoc false
  # Scaling, flipping and rotating "around" a point. Curves are always scaled and rotated around
  # their own {0, 0} and then moved to their position (see Curves.Transform). To turn around some
  # other point instead, the position is moved so that the pivot ends up exactly where it was.
  alias Curves.Types, as: T
  alias Curves.Utils.Vec

  # nil (around the curve's own {0, 0}), :center (the middle of the curve's points), or a point,
  # all in the curve's own coordinates: the points it was defined with, before any transforms.
  @type around() :: nil | :center | T.point_tuple()

  # Runs `change` (which updates the curve's :scale or :rotation), then moves the curve so that the
  # pivot is where it was before. Example: rotating a curve 180 degrees around its middle point
  # would otherwise swing it to the other side of its position; the shift brings it back.
  @spec keep_in_place(T.curve_data(), around(), (T.curve_data() -> T.curve_data())) ::
          T.curve_data()
  def keep_in_place(curve, nil, change), do: change.(curve)

  def keep_in_place(curve, around, change) do
    pivot = resolve(curve, around)
    changed = change.(curve)
    shift = Vec.subtract(place(curve, pivot), place(changed, pivot))
    %{changed | origin: Vec.add(changed.origin, shift)}
  end

  # Where the curve's own point ends up after scaling and rotating, before it is moved.
  @spec place(T.curve_data(), T.point_tuple()) :: T.point_tuple()
  defp place(%{scale: scale, rotation: rotation}, point),
    do: point |> Vec.scale(scale) |> Vec.rotate(rotation, {0.0, 0.0})

  # The middle of the curve's bounding box, or the point given (as floats).
  @spec resolve(T.curve_data(), :center | T.point_tuple()) :: T.point_tuple()
  defp resolve(%{xmin: xmin, xmax: xmax, ymin: ymin, ymax: ymax}, :center),
    do: {(xmin + xmax) / 2, (ymin + ymax) / 2}

  defp resolve(_curve, point), do: Vec.new(point)
end
