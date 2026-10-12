defmodule Curves.Svg.DrawingWriter do
  @moduledoc false
  # Draws a Curves.Drawing as designed (Curves.Svg's :design mode): in its own coordinates and view
  # box, with its groups, its shapes' own styles and its kept markup, so it looks like the SVG it was
  # read from. Each shape is one <path>: its curves written exactly as path data (see
  # Curves.Svg.PathWriter), in the shape's own coordinates, with its transform on the element, so
  # strokes are as wide as they were.
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Node, Raw, Shape}
  alias Curves.Svg.{Import, PathWriter, TransformList}
  alias Curves.Types, as: T
  alias Curves.Utils.{Matrix, Vec}

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
      placed(Node.matrix(drawing), Enum.map(drawing.children, &child/1)),
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

  # A drawing's own move, scale and rotation (from Curves.Transform) go on a <g> around everything,
  # so kept markup like text moves with the shapes.
  @spec placed(Matrix.t(), iodata()) :: iodata()
  defp placed(matrix, content), do: placed(matrix, content, Matrix.identity?(matrix))

  @spec placed(Matrix.t(), iodata(), boolean()) :: iodata()
  defp placed(_matrix, content, true = _identity), do: content
  defp placed(matrix, content, false), do: [~s(<g#{transform(matrix)}>\n), content, "</g>\n"]

  @spec child(Drawing.child()) :: iodata()
  defp child(%Group{element: element, attributes: attributes, children: children} = group) do
    [
      "<",
      element,
      optional_transform(Node.matrix(group)),
      attributes(attributes, ["transform"]),
      ">\n",
      Enum.map(children, &child/1),
      "</",
      element,
      ">\n"
    ]
  end

  defp child(%Shape{subpaths: subpaths, attributes: attributes, transform: matrix} = shape) do
    {kept, move} = own_coordinates(matrix)

    d =
      Enum.map_join(subpaths, " ", fn subpath ->
        PathWriter.path_data(subpath.curve, move) <> close(subpath.closed)
      end)

    transform = optional_transform(Matrix.multiply(Node.matrix(shape), kept))
    [~s(<path d="#{d}"), transform, attributes(attributes, @geometry), "/>\n"]
  end

  defp child(%Raw{markup: markup, transform: matrix}),
    do: placed(matrix, [markup, "\n"])

  @spec close(boolean()) :: String.t()
  defp close(true), do: " Z"
  defp close(false), do: ""

  # A shape's curves are where its SVG transform put them. To draw it as the SVG did, they are moved
  # back into its own coordinates, and that transform is kept, to go on the element. A transform
  # that squashes everything flat can't be undone, so then the curves are written as they are, and
  # no transform is kept.
  @spec own_coordinates(Matrix.t()) :: {Matrix.t(), (T.point_tuple() -> T.point_tuple())}
  defp own_coordinates({a, b, c, d, _e, _f} = matrix) do
    det = a * d - b * c
    invertible = abs(det) > 1.0e-12 * max(1.0, abs(a * d) + abs(b * c))
    undo(matrix, det, invertible)
  end

  @spec undo(Matrix.t(), float(), boolean()) :: {Matrix.t(), (T.point_tuple() -> T.point_tuple())}
  defp undo(_matrix, _det, false), do: {Matrix.identity(), &Function.identity/1}

  defp undo({a, b, c, d, e, f} = matrix, det, true) do
    inverse = {d / det, -b / det, -c / det, a / det, (c * f - d * e) / det, (b * e - a * f) / det}
    {matrix, &Matrix.move(inverse, &1)}
  end

  # ` transform="..."`, or nothing for a transform that changes nothing.
  @spec optional_transform(Matrix.t()) :: String.t()
  defp optional_transform(matrix), do: optional_transform(matrix, Matrix.identity?(matrix))

  @spec optional_transform(Matrix.t(), boolean()) :: String.t()
  defp optional_transform(_matrix, true = _identity), do: ""
  defp optional_transform(matrix, false), do: transform(matrix)

  @spec transform(TransformList.matrix()) :: String.t()
  defp transform(matrix) do
    # + 0.0 writes -0.0 (e.g. from rotating by 0) as 0.0.
    numbers = matrix |> Tuple.to_list() |> Enum.map_join(" ", &PathWriter.number(&1 + 0.0))
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
