defmodule Curves.Utils.Plotting do
  #@moduledoc ~s"""
  #These are helper functions for making it easier to plot curves with VegaLite.
  #"""
  @moduledoc false
  import Curves.Utils.Points, only: [to_maps: 1]

  @doc ~s"""
  Given a curve, build a list of points, in map format.

  ## Opts
  * `:label`, default: `"Curve"`
  * `:count`, default: `1000`
  """
  def curve_to_scatterplot(curve), do: curve_to_scatterplot(curve, [])
  def curve_to_scatterplot(%Curves.Bezier.Curve{} = curve, opts) do
    control_points = extract_control_points(curve)

    label = Keyword.get(opts, :label, "Curve")
    count = Keyword.get(opts, :count, 1000)
    line = Curves.take!(curve, count, opts)
      |> Enum.map(fn {x, y} ->
        %{x: x, y: y, label: label}
      end)
    line ++ control_points
  end
  def curve_to_scatterplot(%Curves.Spline.Curve{} = curve, opts) do
    control_points = extract_control_points(curve)

    label = Keyword.get(opts, :label, "Curve")
    count = Keyword.get(opts, :count, 1000)
    line = Curves.take_spline!(curve, count, opts)
      |> Enum.map(fn {x, y} ->
        %{x: x, y: y, label: label}
      end)
    line ++ control_points
  end

  @doc false
  #Given a curve, get a list of the control points, in map format.
  defp extract_control_points(%Curves.Bezier.Curve{points: points}) do
    case Nx.shape(points) do
      {_, n} when n < 3 -> []
      {_, n} -> 
        Nx.slice(points, [0, 1], [2, n - 2])
          |> to_maps()
    end
      |> Enum.with_index()
      |> Enum.map(fn {p, idx} -> 
        Map.put(p, :label, "control point #{idx}")
      end)
  end
  defp extract_control_points(%Curves.Spline.Curve{segments: segments}) do
    Nx.to_list(segments)
      |> Enum.with_index()
      |> Enum.map(fn {segment, segment_idx} ->
          Enum.zip_with(segment, fn [x, y] ->
            %{x: x, y: y, label: "segment #{segment_idx} {#{Float.round(x, 3)}, #{Float.round(y, 3)}}"}
          end)
      end)
      |> List.flatten()
  end


end
