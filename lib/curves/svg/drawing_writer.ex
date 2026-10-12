defmodule Curves.Svg.DrawingWriter do
  @moduledoc false
  # Draws a Curves.Drawing as designed (Curves.Svg's :design mode): in its own coordinates and view
  # box, with its groups, its shapes' own styles and its kept markup, so it looks like the SVG it was
  # read from. Each shape is one <path>: its curves written exactly as path data (see
  # Curves.Svg.PathWriter), in the shape's own coordinates, with its transform on the element, so
  # strokes are as wide as they were.
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Raw, Shape}
  alias Curves.Svg.{Import, PathWriter, TransformList}
  alias Curves.Types, as: T
  alias Curves.Utils.Vec

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  # Attributes that describe a shape's geometry (now in its path data) or its transform (now on
  # the element), so they aren't copied.
  @geometry ~w(d points x y width height rx ry cx cy r x1 y1 x2 y2 transform)

  # The <svg> element's attributes that are written fresh.
  @root ~w(xmlns width height viewBox transform)

  @defaults [
    background: nil,
    show_points: false,
    point_color: "#d9480f",
    point_radius: 5,
    show_polygon: false,
    polygon_color: "#adb5bd",
    markers: [],
    marker_color: "#7048e8",
    marker_radius: 7,
    title: nil
  ]

  @spec render(Drawing.t(), keyword()) :: String.t()
  def render(%Drawing{} = drawing, opts) do
    opts = Keyword.merge(@defaults, opts)
    {vx, vy, vw, vh} = box = view_box(drawing, opts[:view])
    width = opts[:width] || drawing.width || PathWriter.number(vw)
    height = opts[:height] || drawing.height || PathWriter.number(vh)

    # Pixels per unit, to keep dots and the title the same size on screen (1 if the size has units).
    scale = pixels_per_unit(width, height, vw, vh)

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{escape(width)}" height="#{escape(height)}" viewBox="#{Enum.map_join([vx, vy, vw, vh], " ", &PathWriter.number/1)}"#{attributes(drawing.attributes, @root)}>\n),
      background(opts[:background], box),
      Enum.map(drawing.children, &child/1),
      overlays(drawing, opts, scale),
      title(opts[:title], box, scale),
      "</svg>\n"
    ]
    |> IO.iodata_to_binary()
  end

  # The :view option's corners, the drawing's own view box, or the box around its curves.
  @spec view_box(Drawing.t(), term()) :: {float(), float(), float(), float()}
  defp view_box(_drawing, {corner1, corner2}) when is_tuple(corner1) and is_tuple(corner2),
    do: box([Vec.new(corner1), Vec.new(corner2)])

  defp view_box(drawing, nil), do: drawing.view_box || drawing |> sampled_points() |> box()

  defp view_box(_drawing, other) do
    raise ArgumentError,
          ":view must be two corners {{x1, y1}, {x2, y2}}, or nil, got: #{inspect(other)}"
  end

  @spec sampled_points(Drawing.t()) :: T.point_list()
  defp sampled_points(drawing) do
    Enum.flat_map(Drawing.curves(drawing), &[Curves.solve!(&1, 0.0) | Curves.take!(&1, 100)])
  end

  # The box around some points, never 0 wide or high. Nothing at all gives the box 0..100.
  @spec box(T.point_list()) :: {float(), float(), float(), float()}
  defp box([]), do: {0.0, 0.0, 100.0, 100.0}

  defp box(points) do
    %{xmin: xmin, xmax: xmax, ymin: ymin, ymax: ymax} = Vec.bounds(points)
    {xmin * 1.0, ymin * 1.0, max(xmax - xmin, 1.0e-9) * 1.0, max(ymax - ymin, 1.0e-9) * 1.0}
  end

  @spec pixels_per_unit(term(), term(), float(), float()) :: float()
  defp pixels_per_unit(width, height, vw, vh) do
    with {:ok, w} <- pixels(width), {:ok, h} <- pixels(height), true <- w > 0 and h > 0 do
      min(w / vw, h / vh)
    else
      _ -> 1.0
    end
  end

  # A width or height as a number of pixels, if it is one.
  @spec pixels(term()) :: {:ok, float()} | :error
  defp pixels(n) when is_number(n), do: {:ok, n * 1.0}

  defp pixels(text) when is_binary(text) do
    case Curves.Svg.PathData.number(text) do
      {:ok, value, rest} when rest in ["", "px"] -> {:ok, value}
      _ -> :error
    end
  end

  defp pixels(_other), do: :error

  @spec background(String.t() | nil, tuple()) :: iodata()
  defp background(nil, _box), do: []

  defp background(color, {x, y, w, h}) do
    ~s(  <rect x="#{n(x)}" y="#{n(y)}" width="#{n(w)}" height="#{n(h)}" fill="#{escape(color)}"/>\n)
  end

  ## The drawing's own content

  @spec child(Drawing.child()) :: iodata()
  defp child(%Group{element: element, attributes: attributes, children: children}) do
    [
      "<",
      element,
      attributes(attributes, ["transform"]),
      ">\n",
      Enum.map(children, &child/1),
      "</",
      element,
      ">\n"
    ]
  end

  defp child(%Shape{subpaths: subpaths, attributes: attributes, transform: matrix}) do
    {transform, move} = own_coordinates(matrix)

    d =
      Enum.map_join(subpaths, " ", fn subpath ->
        PathWriter.path_data(subpath.curve, move) <> close(subpath.closed)
      end)

    [~s(<path d="#{d}"), transform, attributes(attributes, @geometry), "/>\n"]
  end

  defp child(%Raw{markup: markup, transform: matrix}) when matrix == @identity, do: [markup, "\n"]

  defp child(%Raw{markup: markup, transform: matrix}),
    do: [~s(<g#{transform(matrix)}>), markup, "</g>\n"]

  @spec close(boolean()) :: String.t()
  defp close(true), do: " Z"
  defp close(false), do: ""

  # A shape's curves are where it is drawn (its transform already applied). To draw it as the SVG
  # did, they are moved back into its own coordinates, and the transform goes on the element. A
  # transform that squashes everything flat can't be undone, so then the curves are written as
  # they are, with no transform.
  @spec own_coordinates(TransformList.matrix()) ::
          {String.t(), (T.point_tuple() -> T.point_tuple())}
  defp own_coordinates(matrix) when matrix == @identity, do: {"", &Function.identity/1}

  defp own_coordinates({a, b, c, d, _e, _f} = matrix) do
    det = a * d - b * c
    invertible = abs(det) > 1.0e-12 * max(1.0, abs(a * d) + abs(b * c))
    undo(matrix, det, invertible)
  end

  @spec undo(TransformList.matrix(), float(), boolean()) ::
          {String.t(), (T.point_tuple() -> T.point_tuple())}
  defp undo(_matrix, _det, false), do: {"", &Function.identity/1}

  defp undo({a, b, c, d, e, f} = matrix, det, true) do
    inverse = {d / det, -b / det, -c / det, a / det, (c * f - d * e) / det, (b * e - a * f) / det}
    {transform(matrix), &TransformList.move(inverse, &1)}
  end

  @spec transform(TransformList.matrix()) :: String.t()
  defp transform(matrix) do
    numbers = matrix |> Tuple.to_list() |> Enum.map_join(" ", &PathWriter.number/1)
    ~s| transform="matrix(#{numbers})"|
  end

  # ` name="value"` for each attribute but the left-out ones and any that could run code, in name order.
  @spec attributes(map(), list(String.t())) :: iodata()
  defp attributes(attributes, left_out) do
    attributes
    |> Enum.reject(fn {name, _} = attribute ->
      name in left_out or Import.unsafe_attribute?(attribute)
    end)
    |> Enum.sort()
    |> Enum.map(fn {name, value} -> [" ", name, "=\"", escape(value), "\""] end)
  end

  ## Curves.Svg's extras, in the drawing's own units

  @spec overlays(Drawing.t(), keyword(), float()) :: iodata()
  defp overlays(drawing, opts, scale) do
    curves = Drawing.curves(drawing)

    [
      polygons(opts[:show_polygon], curves, opts, scale),
      dots(opts[:show_points], curves, opts, scale),
      Enum.map(
        opts[:markers],
        &circle(Vec.new(&1), opts[:marker_radius] / scale, opts[:marker_color])
      )
    ]
  end

  @spec polygons(term(), list(), keyword(), float()) :: iodata()
  defp polygons(show, _curves, _opts, _scale) when show in [false, nil], do: []

  defp polygons(_show, curves, opts, scale) do
    for curve <- curves, line <- Curves.Svg.control_lines(curve) do
      points = Enum.map_join(line, " ", fn {x, y} -> "#{n(x)},#{n(y)}" end)

      ~s(  <polyline points="#{points}" fill="none" stroke="#{escape(opts[:polygon_color])}" stroke-width="#{n(1.5 / scale)}" stroke-dasharray="#{n(6 / scale)} #{n(4 / scale)}"/>\n)
    end
  end

  @spec dots(term(), list(), keyword(), float()) :: iodata()
  defp dots(show, _curves, _opts, _scale) when show in [false, nil], do: []

  defp dots(_show, curves, opts, scale) do
    for curve <- curves, point <- Curves.Svg.control_points(curve) do
      circle(point, opts[:point_radius] / scale, opts[:point_color])
    end
  end

  @spec circle(T.point_tuple(), float(), String.t()) :: String.t()
  defp circle({x, y}, r, color),
    do: ~s(  <circle cx="#{n(x)}" cy="#{n(y)}" r="#{n(r)}" fill="#{escape(color)}"/>\n)

  @spec title(String.t() | nil, tuple(), float()) :: iodata()
  defp title(nil, _box, _scale), do: []

  defp title(text, {x, y, _w, _h}, scale) do
    ~s(  <text x="#{n(x + 10 / scale)}" y="#{n(y + 24 / scale)}" font-family="sans-serif" font-size="#{n(16 / scale)}" fill="#212529">#{escape(text)}</text>\n)
  end

  @spec n(number()) :: String.t()
  defp n(number), do: PathWriter.number(number)

  @spec escape(term()) :: String.t()
  defp escape(value), do: value |> to_string() |> Import.escape()
end
