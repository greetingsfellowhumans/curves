defmodule Curves.Svg.DrawingWriter do
  @moduledoc false
  # Draws a Curves.Drawing as designed (Curves.Svg's :design mode): in its own coordinates and view
  # box, with its groups, its shapes' own styles and its kept markup, so it looks like the SVG it was
  # read from. Each shape is one <path>: its curves written exactly as path data (see
  # Curves.Svg.PathWriter), in the shape's own coordinates, with its transform on the element, so
  # strokes are as wide as they were.
  #
  # Each group is drawn with its own SVG transform, as it was, so a clip-path, mask or filter on it
  # is read in the same coordinates, and a <use> of a shape inside it gets only the shape's own
  # transform. The shapes and markup in a group have every transform around them (Shape.transform,
  # Raw.transform, Group.transform), so each is written with the group's undone: its transform is
  # the group's undone, then its own. A group whose transform squashes everything flat can't be
  # undone, so then it is drawn without it, as before.
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Node, Raw, Shape}
  alias Curves.Svg.{Import, PathWriter, TransformList}
  alias Curves.Types, as: T
  alias Curves.Utils.{Extremes, Matrix, Vec}

  # The transform a group's content is written in, and the matrix that undoes it.
  @typep frame() :: {Matrix.t(), Matrix.t()}

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
    width = opts[:width] || drawing.width || fitted_size(drawing, vw)
    height = opts[:height] || drawing.height || fitted_size(drawing, vh)

    # Pixels per unit, to keep dots and the title the same size on screen (1 if the size has units).
    scale = pixels_per_unit(width, height, vw, vh)
    top = {Matrix.identity(), Matrix.identity()}

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg"#{size("width", width)}#{size("height", height)} viewBox="#{Enum.map_join([vx, vy, vw, vh], " ", &PathWriter.number/1)}"#{attributes(drawing.attributes, @root)}>\n),
      background(opts[:background], box),
      placed(Node.matrix(drawing), Enum.map(drawing.children, &child(&1, top))),
      overlays(drawing, opts, scale),
      title(opts[:title], box, scale),
      "</svg>\n"
    ]
    |> IO.iodata_to_binary()
  end

  # The :view option's corners, the drawing's own view box, the one its size implies, or the box
  # around its curves.
  @spec view_box(Drawing.t(), term()) :: {float(), float(), float(), float()}
  defp view_box(_drawing, {corner1, corner2}) when is_tuple(corner1) and is_tuple(corner2),
    do: box([Vec.new(corner1), Vec.new(corner2)])

  defp view_box(drawing, nil) do
    drawing.view_box || implied_view_box(drawing) ||
      drawing |> Drawing.curves() |> Enum.flat_map(&Extremes.points/1) |> box()
  end

  defp view_box(_drawing, other) do
    raise ArgumentError,
          ":view must be two corners {{x1, y1}, {x2, y2}}, or nil, got: #{inspect(other)}"
  end

  # An SVG with a size in pixels but no viewBox shows 0..width by 0..height, one unit per pixel
  # (flipped like a real view box when it was read with flip_y). nil for any other size. A drawing
  # saved before :read_with_flip_y existed has no such key, so it counts as not flipped.
  @spec implied_view_box(Drawing.t()) :: {float(), float(), float(), float()} | nil
  defp implied_view_box(drawing) do
    flipped = Map.get(drawing, :read_with_flip_y, false)
    implied_view_box(pixels(drawing.width), pixels(drawing.height), flipped)
  end

  @spec implied_view_box({:ok, float()} | :error, {:ok, float()} | :error, boolean()) ::
          {float(), float(), float(), float()} | nil
  defp implied_view_box({:ok, w}, {:ok, h}, true = _flipped) when w > 0 and h > 0,
    do: {0.0, -h, w, h}

  defp implied_view_box({:ok, w}, {:ok, h}, false) when w > 0 and h > 0, do: {0.0, 0.0, w, h}
  defp implied_view_box(_width, _height, _flipped), do: nil

  # The box around some points. Nothing at all gives the box 0..100.
  @spec box(T.point_list()) :: {float(), float(), float(), float()}
  defp box([]), do: {0.0, 0.0, 100.0, 100.0}

  defp box(points) do
    %{xmin: xmin, xmax: xmax, ymin: ymin, ymax: ymax} = Vec.bounds(points)
    {x, width} = span(xmin, xmax)
    {y, height} = span(ymin, ymax)
    {x, y, width, height}
  end

  # Where the box starts on one axis, and how big it is. Flat content (a straight line along the
  # other axis, or a single point) gets 1 unit, centred on it, so it can still be seen.
  @spec span(number(), number()) :: {float(), float()}
  defp span(low, high) when high - low > 1.0e-9, do: {low * 1.0, (high - low) * 1.0}
  defp span(low, high), do: {(low + high) / 2 - 0.5, 1.0}

  # The width or height to write when the drawing has none. A drawing with a view box of its own
  # had none either, so none is written, and it fills the space it is shown in, as it did. Otherwise
  # the box was made up to fit the curves, so it is drawn one pixel per unit.
  @spec fitted_size(Drawing.t(), float()) :: String.t() | nil
  defp fitted_size(%Drawing{view_box: nil}, size), do: PathWriter.number(size)
  defp fitted_size(_drawing, _size), do: nil

  # ` width="..."`, or nothing.
  @spec size(String.t(), term()) :: String.t()
  defp size(_name, nil), do: ""
  defp size(name, value), do: ~s( #{name}="#{escape(value)}")

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
  defp placed(matrix, content), do: placed(tidy(matrix), content, Matrix.identity?(tidy(matrix)))

  @spec placed(Matrix.t(), iodata(), boolean()) :: iodata()
  defp placed(_matrix, content, true = _identity), do: content
  defp placed(matrix, content, false), do: [~s(<g#{transform(matrix)}>\n), content, "</g>\n"]

  # A shape, group or kept markup, inside a group (or the drawing) whose content is written in
  # `outer`.
  @spec child(Drawing.child(), frame()) :: iodata()
  defp child(%Group{element: element, attributes: attributes, children: children} = group, outer) do
    {_chain, undo_outer} = outer
    {chain, _undo} = inner = frame(group.transform, outer)
    matrix = Matrix.multiply(undo_outer, Matrix.multiply(Node.matrix(group), chain))

    [
      "<",
      element,
      optional_transform(matrix),
      attributes(attributes, ["transform"]),
      ">\n",
      Enum.map(children, &child(&1, inner)),
      "</",
      element,
      ">\n"
    ]
  end

  defp child(%Shape{subpaths: subpaths, attributes: attributes, transform: matrix} = shape, outer) do
    {_chain, undo_outer} = outer
    {kept, move} = own_coordinates(matrix)
    d = Enum.map_join(subpaths, " ", &subpath_data(&1, move))
    transform = Matrix.multiply(undo_outer, Matrix.multiply(Node.matrix(shape), kept))
    [~s(<path d="#{d}"), optional_transform(transform), attributes(attributes, @geometry), "/>\n"]
  end

  defp child(%Raw{markup: markup, transform: matrix}, {_chain, undo_outer}),
    do: placed(Matrix.multiply(undo_outer, matrix), [markup, "\n"])

  # A subpath's path data, with Z after it if it is closed.
  @spec subpath_data(Drawing.Subpath.t(), (T.point_tuple() -> T.point_tuple())) :: String.t()
  defp subpath_data(%{curve: curve, closed: true}, move),
    do: PathWriter.closed_path_data(curve, move) <> " Z"

  defp subpath_data(%{curve: curve, closed: false}, move), do: PathWriter.path_data(curve, move)

  # What a group's content is written in: the group's transform, or the one around it if the
  # group's can't be undone.
  @spec frame(Matrix.t(), frame()) :: frame()
  defp frame(transform, outer), do: frame(transform, inverse(transform), outer)

  @spec frame(Matrix.t(), {:ok, Matrix.t()} | :error, frame()) :: frame()
  defp frame(transform, {:ok, undo}, _outer), do: {transform, undo}
  defp frame(_transform, :error, outer), do: outer

  # A shape's curves are where its SVG transform put them. To draw it as the SVG did, they are moved
  # back into its own coordinates, and that transform is kept, to go on the element. A transform
  # that squashes everything flat can't be undone, so then the curves are written as they are, and
  # no transform is kept.
  @spec own_coordinates(Matrix.t()) :: {Matrix.t(), (T.point_tuple() -> T.point_tuple())}
  defp own_coordinates(matrix), do: undo(matrix, inverse(matrix))

  @spec undo(Matrix.t(), {:ok, Matrix.t()} | :error) ::
          {Matrix.t(), (T.point_tuple() -> T.point_tuple())}
  defp undo(_matrix, :error), do: {Matrix.identity(), &Function.identity/1}
  defp undo(matrix, {:ok, inverse}), do: {matrix, &Matrix.move(inverse, &1)}

  # The matrix that undoes `matrix`, or :error for one that squashes everything flat.
  @spec inverse(Matrix.t()) :: {:ok, Matrix.t()} | :error
  defp inverse({a, b, c, d, _e, _f} = matrix) do
    det = a * d - b * c
    inverse(matrix, det, abs(det) > 1.0e-12 * max(1.0, abs(a * d) + abs(b * c)))
  end

  @spec inverse(Matrix.t(), float(), boolean()) :: {:ok, Matrix.t()} | :error
  defp inverse(_matrix, _det, false = _invertible), do: :error

  defp inverse({a, b, c, d, e, f}, det, true),
    do:
      {:ok, {d / det, -b / det, -c / det, a / det, (c * f - d * e) / det, (b * e - a * f) / det}}

  # Undoing a group's transform leaves rounding errors, like 0.9999999999999999 or 1.0e-17, so
  # numbers that close to a whole number are written as it.
  @spec tidy(Matrix.t()) :: Matrix.t()
  defp tidy(matrix), do: matrix |> Tuple.to_list() |> Enum.map(&whole/1) |> List.to_tuple()

  @spec whole(float()) :: float()
  defp whole(n), do: whole(n, Float.round(n * 1.0))

  @spec whole(float(), float()) :: float()
  defp whole(n, rounded) when abs(n - rounded) <= 1.0e-12 * max(1.0, abs(n)), do: rounded
  defp whole(n, _rounded), do: n

  # ` transform="..."`, or nothing for a transform that changes nothing.
  @spec optional_transform(Matrix.t()) :: String.t()
  defp optional_transform(matrix),
    do: optional_transform(tidy(matrix), Matrix.identity?(tidy(matrix)))

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
