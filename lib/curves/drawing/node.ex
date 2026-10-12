defmodule Curves.Drawing.Node do
  @moduledoc false
  # What drawings, groups and shapes share: their own move, scale and rotation, set by the
  # Curves.Transform functions exactly as on a curve (scale, then rotate around {0, 0}, then move).
  #
  # A node's transform isn't folded into its curves: it stays on the node, so it can be set again
  # (set_scale(drawing, 0) and then set_scale(drawing, 1) loses nothing), and Curves.Svg puts it on
  # a <g> or <path>, which moves kept markup like text along with the shapes. Curves.Drawing.shapes/1
  # and curves/1 apply it, so the curves they give are where they are drawn.
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Shape}
  alias Curves.Polyline.Curve, as: Polyline
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Types, as: T
  alias Curves.Utils.{Errors, Matrix, Vec}

  @type t() :: Drawing.t() | Group.t() | Shape.t()

  # The node's own transform as a matrix.
  @spec matrix(t()) :: Matrix.t()
  def matrix(%{origin: origin, scale: scale, rotation: rotation}),
    do: Matrix.trs(origin, scale, rotation)

  # Applies a change from Curves.Transform ({module, function, arguments}, the same ones a curve
  # gets) to the node's own move, scale and rotation. around: :center is the middle of everything
  # in the node, before its own transform.
  @spec transform(t(), {module(), atom(), list()}) :: t()
  def transform(node, {mod, func, args}) do
    state = Map.merge(bounds(node), Map.take(node, [:origin, :scale, :rotation]))
    changed = apply(mod, func, [state | args])
    %{node | origin: changed.origin, scale: changed.scale, rotation: changed.rotation}
  end

  # The box around the node's content, in its own coordinates (before its own transform).
  @spec bounds(t()) :: %{xmin: float(), xmax: float(), ymin: float(), ymax: float()}
  defp bounds(node) do
    case node |> unplaced() |> content_points() do
      [] -> %{xmin: 0.0, xmax: 0.0, ymin: 0.0, ymax: 0.0}
      points -> Vec.bounds(points)
    end
  end

  @spec unplaced(t()) :: t()
  defp unplaced(node), do: %{node | origin: {0.0, 0.0}, scale: 1.0, rotation: 0.0}

  @spec content_points(t()) :: T.point_list()
  defp content_points(%Shape{subpaths: subpaths}),
    do: Enum.flat_map(subpaths, &curve_points(&1.curve))

  defp content_points(container),
    do: container |> Drawing.shapes() |> Enum.flat_map(&content_points/1)

  # A curve's points (knots and control points) where they are drawn.
  @spec curve_points(T.curve_struct()) :: T.point_list()
  def curve_points(curve) do
    cond do
      is_struct(curve, Bezier) -> Bezier.transformed_points(curve)
      is_struct(curve, Spline) -> Spline.transformed_points(curve)
      is_struct(curve, Polyline) -> Polyline.transformed_points(curve)
      true -> Errors.raise_not_a_curve(curve)
    end
  end

  # A curve moved by a matrix, as it is drawn.
  @spec move_curve(T.curve_struct(), Matrix.t()) :: T.curve_struct()
  def move_curve(curve, matrix) do
    move = &Matrix.move(matrix, &1)

    cond do
      is_struct(curve, Bezier) -> Bezier.map_points(curve, move)
      is_struct(curve, Spline) -> Spline.map_points(curve, move)
      is_struct(curve, Polyline) -> Polyline.map_points(curve, move)
      true -> Errors.raise_not_a_curve(curve)
    end
  end
end
