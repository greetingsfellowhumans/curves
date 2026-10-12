defmodule Curves.Svg do
  @moduledoc ~s"""
  Draws a curve (a Bezier, a spline or a polyline) as an SVG image, using only Elixir.

  The curve is solved at `:samples` evenly spaced points from start to end, and those points are joined with a line.
  The curve's own points are drawn as dots, and the image is scaled to fit while keeping the curve's shape.

  ```elixir
  curve = Curves.define_b_spline([{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}])
  Curves.Svg.save!(curve, "b_spline.svg", title: "B-Spline")
  ```

  `path_data/1` gives a curve as exact SVG path data instead, for your own `<path>` elements.

  ## Drawings

  A `Curves.Drawing` (from `Curves.from_svg/2`) is drawn **as designed** by default (`mode: :design`):
  in its own size and view box, with its groups, each shape's own styles (`fill`, `stroke`, `class`,
  ...) and its kept markup (text, `<defs>`, ...), so it looks like the SVG it was read from. Each
  shape is one `<path>`, its curves written exactly with `path_data/1`, and its `transform` kept on
  it so strokes are as wide as they were.

  ```elixir
  drawing = Curves.from_svg(File.read!("logo.svg"))
  Curves.Svg.save!(drawing, "logo_again.svg")
  ```

  As designed, the options that apply are `:width`, `:height` and `:view` (to frame it differently),
  `:background` (none by default), `:title`, `:markers`, and `:show_points` and `:show_polygon`
  (off by default) with their colours and sizes, which are in pixels as usual. The rest are for
  curves.

  `mode: :inspect` draws a drawing like a curve instead: every curve in the curve colour, fitted
  together, with y going up, dots, dashed lines and the grid. Pass `flip_y: true` to
  `Curves.from_svg/2` to have it the right way up then.

  ## Options

  | `key` | `default` | `description` |
  | --- | --- | --- |
  | `:samples` | `100` | How many points to solve along the curve, not counting the start. More gives a smoother line. |
  | `:width` | `600` | Image width in pixels. |
  | `:height` | `600` | Image height in pixels. |
  | `:padding` | `40` | Empty space around the curve, in pixels. |
  | `:background` | `"#ffffff"` | Background colour. `nil` leaves it transparent. |
  | `:curve_color` | `"#1c7ed6"` | Colour of the curve. |
  | `:curve_width` | `3` | Thickness of the curve. |
  | `:show_points` | `true` | Draw the curve's own points as dots. |
  | `:point_color` | `"#d9480f"` | Colour of the dots. |
  | `:point_radius` | `5` | Size of the dots. |
  | `:show_polygon` | `true` | Draw dashed lines showing how the curve's points shape it. For beziers and bezier splines they go from each control point to the knot it pulls on; for other splines one line joins the points in order. |
  | `:polygon_color` | `"#adb5bd"` | Colour of that dashed line. |
  | `:view` | `nil` | The area to draw, as two opposite corners: `{{x1, y1}, {x2, y2}}`. `nil` fits the picture to the curve. A fixed view keeps several pictures (or the frames of an animation) at the same scale, so you can see a curve move and grow. Anything outside it is cut off. |
  | `:markers` | `[]` | Extra `{x, y}` points to highlight, e.g. `[Curves.solve!(curve, 0.5)]` to show where `t = 0.5` lands. They are in the same coordinates `Curves.solve/3` returns. |
  | `:marker_color` | `"#7048e8"` | Colour of the markers. |
  | `:marker_radius` | `7` | Size of the markers. |
  | `:title` | `nil` | Text drawn in the top-left corner. |
  | `:show_axes` | `true` | Draw a grid with the x and y values along the bottom and left edges, like a ruler. The lines at x = 0 and y = 0 are darker. The image is always scaled to fit, so without the grid a curve looks the same at any size. The numbers sit in the padding, so a small `:padding` hides them. `false` turns the grid off. |
  | `:axis_color` | `"#868e96"` | Colour of the grid lines and their numbers. |
  | `:solve_opts` | `[]` | Options passed to `Curves.take!/3` and `Curves.solve!/3`. |
  | `:mode` | `:inspect` (curves), `:design` (drawings) | How to draw a `Curves.Drawing`: as designed, or like a curve. See "Drawings" above. A curve is always drawn like this, in `:inspect` mode. |

  The `show_*` options treat `nil` like `false`.

  The dots are the points the curve stores. For most curves these are the points you defined it with,
  but B-splines store the control points they generate from yours, and ellipses and arcs store the
  corners of the shape they stay inside (see `Curves.Spline.Type.Ellipse`).

  If `:solve_opts` turns on `:force_percent`, the curve is drawn in 0..1 but its points are not,
  so set `show_points: false` and `show_polygon: false`.
  For example, the grid shows that a scaled curve is bigger, even though the image fits it to the same size:

  ```elixir
  curve = Curves.define_bezier(:ease_in_out) |> Curves.Transform.set_scale(10)
  Curves.Svg.render(curve)
  ```
  """
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Drawing
  alias Curves.Polyline.Curve, as: Polyline
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Types, as: T
  alias Curves.Utils.{Errors, Vec}

  # How curve coordinates map to pixels; see view/2.
  @typep view :: %{
           xmin: number(),
           ymin: number(),
           scale: number(),
           offset_x: number(),
           offset_y: number(),
           height: number()
         }

  @defaults [
    samples: 100,
    width: 600,
    height: 600,
    padding: 40,
    background: "#ffffff",
    curve_color: "#1c7ed6",
    curve_width: 3,
    show_points: true,
    point_color: "#d9480f",
    point_radius: 5,
    show_polygon: true,
    polygon_color: "#adb5bd",
    title: nil,
    view: nil,
    markers: [],
    marker_color: "#7048e8",
    marker_radius: 7,
    show_axes: true,
    axis_color: "#868e96",
    solve_opts: []
  ]

  @doc ~s"""
  Builds the SVG for a curve, or for every curve in a `Curves.Drawing`, and returns it as a string.

  See the module docs for `opts`, including `:samples` for how smooth the line is.

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> svg = Curves.Svg.render(curve, width: 100, height: 100)
      iex> String.starts_with?(svg, "<svg")
      true
      iex> svg =~ ~s(<circle cx="40.00" cy="60.00")
      true

  A drawing is drawn as designed: each shape is a `<path>`, with its own style.

      iex> drawing = Curves.from_svg(~s(<svg><circle r="2" fill="red"/><path d="M0 0 L4 4 M0 4 L4 0"/></svg>))
      iex> svg = Curves.Svg.render(drawing)
      iex> svg =~ ~s(<path d="M0.0,0.0 L4.0,4.0 M0.0,4.0 L4.0,0.0"/>)
      true
      iex> svg =~ ~s( fill="red"/>)
      true
  """
  @spec render(T.curve_struct() | Drawing.t(), keyword()) :: String.t()
  def render(curve_or_drawing, opts \\ [])

  def render(%Drawing{} = drawing, opts),
    do: render_drawing(Keyword.get(opts, :mode, :design), drawing, opts)

  def render(curve, opts) do
    case Keyword.get(opts, :mode, :inspect) do
      :inspect ->
        inspect_render(curve, opts)

      other ->
        raise ArgumentError,
              ":mode must be :inspect for a curve (:design draws a Curves.Drawing), got: #{inspect(other)}"
    end
  end

  @doc ~s"""
  A curve as SVG path data, the `d` of a `<path>` element: exact, not sampled. A Bezier curve is one
  `L`, `Q` or `C` command; a spline is a `C` command for each segment (whatever kind of spline it
  is, each segment is exactly a cubic Bezier curve) and `A` commands for its arcs; a polyline is `L`
  commands. Every transform is included. Numbers are written as briefly as they can be while
  reading back as exactly the same float.

  It doesn't include `:force_percent`, which changes the numbers `solve` returns, not the curve.

  ## Examples
      iex> Curves.Svg.path_data(Curves.define_bezier([{0, 0}, {1, 2}, {3, 2}, {4, 0}]))
      "M0.0,0.0 C1.0,2.0 3.0,2.0 4.0,0.0"
      iex> Curves.Svg.path_data(Curves.define_polyline([{0, 0}, {2, 1}]) |> Curves.Transform.set_scale(2))
      "M0.0,0.0 L4.0,2.0"
      iex> Curves.Svg.path_data(Curves.define_circle({0, 0}, 1, to: 90))
      "M1.0,0.0 A1.0 1.0 0.0 0 1 6.123233995736766e-17,1.0"
  """
  @spec path_data(T.curve_struct()) :: String.t()
  def path_data(curve), do: Curves.Svg.PathWriter.path_data(curve)

  @spec render_drawing(term(), Drawing.t(), keyword()) :: String.t()
  defp render_drawing(:design, drawing, opts), do: Curves.Svg.DrawingWriter.render(drawing, opts)
  defp render_drawing(:inspect, drawing, opts), do: inspect_render(drawing, opts)

  defp render_drawing(other, _drawing, _opts),
    do: raise(ArgumentError, ":mode must be :design or :inspect, got: #{inspect(other)}")

  # Curves.Svg's own look: fitted to the curves, y going up, with dots, dashed lines and a grid.
  @spec inspect_render(T.curve_struct() | Drawing.t(), keyword()) :: String.t()
  defp inspect_render(curve_or_drawing, opts) do
    opts = Keyword.merge(@defaults, opts)
    curves = curves(curve_or_drawing)
    lines = Enum.map(curves, &sample(&1, opts[:samples], opts[:solve_opts]))
    points = Enum.flat_map(curves, &control_points/1)
    markers = Enum.map(opts[:markers], &Vec.new/1)
    drawn = Enum.concat(lines) ++ shown_points(points, opts) ++ markers
    view = view(area(opts[:view], drawn), opts)
    to_pixels = &to_pixels(view, &1)

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{opts[:width]}" height="#{opts[:height]}" viewBox="0 0 #{opts[:width]} #{opts[:height]}">\n),
      background(opts[:background]),
      axes(opts[:show_axes], view, opts),
      polygon(opts[:show_polygon], Enum.flat_map(curves, &control_lines/1), to_pixels, opts),
      Enum.map(lines, &curve_line(&1, to_pixels, opts)),
      dots(opts[:show_points], points, to_pixels, opts),
      markers(markers, to_pixels, opts),
      title(opts[:title], opts),
      "</svg>\n"
    ]
    |> IO.iodata_to_binary()
  end

  @doc ~s"""
  Builds the SVG for a curve (or a `Curves.Drawing`) with `render/2` and writes it to `path`.
  Returns `path`, and raises if the file can't be written.

  ## Examples
      iex> path = Path.join(System.tmp_dir!(), "curves_svg_doctest.svg")
      iex> curve = Curves.define_bezier(:ease_in_out_cubic)
      iex> Curves.Svg.save!(curve, path, samples: 50)
      iex> File.read!(path) |> String.starts_with?("<svg")
      true
  """
  @spec save!(T.curve_struct() | Drawing.t(), Path.t(), keyword()) :: Path.t()
  def save!(curve, path, opts \\ []) do
    File.write!(path, render(curve, opts))
    path
  end

  # The curves to draw: a drawing's curves (shape by shape), or the one curve.
  @spec curves(T.curve_struct() | Drawing.t()) :: list(T.curve_struct())
  defp curves(%Drawing{} = drawing), do: Drawing.curves(drawing)
  defp curves(curve), do: [curve]

  # One curve's line.
  @spec curve_line(T.point_list(), (T.point_tuple() -> T.point_tuple()), keyword()) :: iodata()
  defp curve_line(line, to_pixels, opts) do
    ~s(  <polyline points="#{polyline(line, to_pixels)}" fill="none" stroke="#{escape(opts[:curve_color])}" stroke-width="#{opts[:curve_width]}" stroke-linejoin="round" stroke-linecap="round"/>\n)
  end

  # The start of the curve plus `samples` evenly spaced points. take!/3 skips the start, so it is added here.
  @spec sample(T.curve_struct(), term(), T.opts()) :: T.point_list()
  defp sample(curve, samples, solve_opts) when is_integer(samples) and samples > 0,
    do: [Curves.solve!(curve, 0.0, solve_opts) | Curves.take!(curve, samples, solve_opts)]

  defp sample(_curve, samples, _solve_opts),
    do: raise(ArgumentError, ":samples must be a positive integer, got: #{inspect(samples)}")

  # The curve's own points that will be drawn, so the image is only sized around what is visible.
  # The show_* options count false and nil as off, and anything else as on.
  @spec shown_points(T.point_list(), keyword()) :: T.point_list()
  defp shown_points(points, opts),
    do: points_if_shown(opts[:show_points] || opts[:show_polygon], points)

  @spec points_if_shown(term(), T.point_list()) :: T.point_list()
  defp points_if_shown(shown, _points) when shown in [false, nil], do: []
  defp points_if_shown(_shown, points), do: points

  # The curve's own points as {x, y} tuples, moved, scaled and rotated like the curve.
  # Repeated neighbours (B-splines store some points twice) are drawn once.
  @doc false
  @spec control_points(T.curve_struct()) :: T.point_list()
  def control_points(curve) do
    cond do
      is_struct(curve, Bezier) -> Bezier.transformed_points(curve)
      is_struct(curve, Spline) -> Spline.transformed_points(curve)
      is_struct(curve, Polyline) -> Polyline.transformed_points(curve)
      true -> Errors.raise_not_a_curve(curve)
    end
    |> Enum.dedup()
  end

  # The dashed lines, moved, scaled and rotated like the curve: for beziers and bezier splines,
  # from each control point to the knot it pulls on; for other splines, one line through all
  # their points. Repeated neighbours are drawn once.
  @doc false
  @spec control_lines(T.curve_struct()) :: list(T.point_list())
  def control_lines(curve) do
    cond do
      is_struct(curve, Bezier) -> Bezier.control_lines(curve)
      is_struct(curve, Spline) -> Spline.control_lines(curve)
      is_struct(curve, Polyline) -> Polyline.control_lines(curve)
      true -> Errors.raise_not_a_curve(curve)
    end
    |> Enum.map(&Enum.dedup/1)
  end

  # The points the picture is fitted to: the two corners of the :view option, or else everything drawn.
  @spec area({T.point_tuple(), T.point_tuple()} | nil, T.point_list()) :: T.point_list()
  # A drawing with no curves (and no markers) has nothing to fit, so it shows the area around {0, 0}.
  defp area(nil, []), do: [{0.0, 0.0}]
  defp area(nil, drawn), do: drawn

  defp area({corner1, corner2}, _drawn) when is_tuple(corner1) and is_tuple(corner2),
    do: [Vec.new(corner1), Vec.new(corner2)]

  defp area(other, _drawn) do
    raise ArgumentError,
          ":view must be two corners {{x1, y1}, {x2, y2}}, or nil, got: #{inspect(other)}"
  end

  # Where the curve sits in the image: how many pixels per unit (the same on both axes, so the
  # shape isn't stretched) and where the lowest x and y land, so the drawing is centred.
  @spec view(T.point_list(), keyword()) :: view()
  defp view(all_points, opts) do
    {xmin, xmax} = all_points |> Enum.map(&elem(&1, 0)) |> Enum.min_max()
    {ymin, ymax} = all_points |> Enum.map(&elem(&1, 1)) |> Enum.min_max()
    inner_w = opts[:width] - 2 * opts[:padding]
    inner_h = opts[:height] - 2 * opts[:padding]
    scale = finite(min(fit(inner_w, xmax - xmin), fit(inner_h, ymax - ymin)))

    %{
      xmin: xmin,
      ymin: ymin,
      scale: scale,
      offset_x: opts[:padding] + (inner_w - (xmax - xmin) * scale) / 2,
      offset_y: opts[:padding] + (inner_h - (ymax - ymin) * scale) / 2,
      height: opts[:height]
    }
  end

  # Maps a curve point to an SVG pixel. y is flipped because SVG's y grows downwards.
  @spec to_pixels(view(), T.point_tuple()) :: T.point_tuple()
  defp to_pixels(view, {x, y}) do
    {view.offset_x + (x - view.xmin) * view.scale,
     view.height - view.offset_y - (y - view.ymin) * view.scale}
  end

  # Pixels per unit along one axis. A flat axis (span 0) doesn't limit the scale.
  @spec fit(number(), number()) :: number() | :infinity
  defp fit(_pixels, span) when span == 0, do: :infinity
  defp fit(pixels, span), do: pixels / span

  # When every point is the same, neither axis limits the scale; any scale works, since the
  # point is drawn at the centre either way.
  @spec finite(number() | :infinity) :: number()
  defp finite(:infinity), do: 1.0
  defp finite(scale), do: scale

  # "x,y x,y ..." for an SVG polyline.
  @spec polyline(T.point_list(), (T.point_tuple() -> T.point_tuple())) :: String.t()
  defp polyline(points, to_pixels),
    do: Enum.map_join(points, " ", &format_point(to_pixels.(&1)))

  @spec format_point(T.point_tuple()) :: String.t()
  defp format_point({x, y}), do: "#{format(x)},#{format(y)}"

  # Two decimal places is well below a pixel.
  @spec format(number()) :: String.t()
  defp format(n), do: :erlang.float_to_binary(n * 1.0, decimals: 2)

  @spec background(String.t() | nil) :: iodata()
  defp background(nil), do: []
  defp background(color), do: ~s(  <rect width="100%" height="100%" fill="#{escape(color)}"/>\n)

  # One dashed polyline per control line.
  @spec polygon(term(), list(T.point_list()), (T.point_tuple() -> T.point_tuple()), keyword()) ::
          iodata()
  defp polygon(show, _lines, _to_pixels, _opts) when show in [false, nil], do: []

  defp polygon(_show, lines, to_pixels, opts) do
    for line <- lines do
      ~s(  <polyline points="#{polyline(line, to_pixels)}" fill="none" stroke="#{escape(opts[:polygon_color])}" stroke-width="1.5" stroke-dasharray="6 4"/>\n)
    end
  end

  @spec dots(term(), T.point_list(), (T.point_tuple() -> T.point_tuple()), keyword()) ::
          iodata()
  defp dots(show, _points, _to_pixels, _opts) when show in [false, nil], do: []

  defp dots(_show, points, to_pixels, opts) do
    for point <- points do
      {x, y} = to_pixels.(point)

      ~s(  <circle cx="#{format(x)}" cy="#{format(y)}" r="#{opts[:point_radius]}" fill="#{escape(opts[:point_color])}"/>\n)
    end
  end

  # The highlighted points from the :markers option, drawn on top with a white ring so they stand out.
  @spec markers(T.point_list(), (T.point_tuple() -> T.point_tuple()), keyword()) :: iodata()
  defp markers(points, to_pixels, opts) do
    for point <- points do
      {x, y} = to_pixels.(point)

      ~s(  <circle cx="#{format(x)}" cy="#{format(y)}" r="#{opts[:marker_radius]}" fill="#{escape(opts[:marker_color])}" stroke="#ffffff" stroke-width="2"/>\n)
    end
  end

  # A grid with numbered ticks along the bottom and left edges, covering the area inside the padding.
  @spec axes(term(), view(), keyword()) :: iodata()
  defp axes(show, _view, _opts) when show in [false, nil], do: []

  defp axes(_show, view, opts) do
    edges =
      {{opts[:padding], opts[:width] - opts[:padding]},
       {opts[:padding], opts[:height] - opts[:padding]}}

    grid(view, edges, opts)
  end

  # `edges` are the left/right and top/bottom pixels of the area inside the padding.
  # When the padding leaves no area, there is nothing to measure (and the scale is 0).
  @spec grid(view(), {{number(), number()}, {number(), number()}}, keyword()) :: iodata()
  defp grid(_view, {{left, right}, {top, bottom}}, _opts) when right <= left or bottom <= top,
    do: []

  defp grid(view, {{left, right}, {top, bottom}}, opts) do
    # The curve values at the edges of that area.
    {x_lo, y_lo} = to_curve(view, {left, bottom})
    {x_hi, y_hi} = to_curve(view, {right, top})
    color = escape(opts[:axis_color])

    x_lines =
      for {x, label} <- ticks(x_lo, x_hi, div(right - left, 70)) do
        {px, _} = to_pixels(view, {x, y_lo})

        [
          grid_line({px, top}, {px, bottom}, x == 0, color),
          ~s(  <text x="#{format(px)}" y="#{bottom + 14}" text-anchor="middle" #{axis_font(color)}>#{label}</text>\n)
        ]
      end

    y_lines =
      for {y, label} <- ticks(y_lo, y_hi, div(bottom - top, 50)) do
        {_, py} = to_pixels(view, {x_lo, y})

        [
          grid_line({left, py}, {right, py}, y == 0, color),
          ~s(  <text x="#{left - 4}" y="#{format(py)}" text-anchor="end" dominant-baseline="middle" #{axis_font(color)}>#{label}</text>\n)
        ]
      end

    [x_lines, y_lines]
  end

  # The opposite of to_pixels/2: which curve point a pixel shows.
  @spec to_curve(view(), {number(), number()}) :: T.point_tuple()
  defp to_curve(view, {px, py}) do
    {view.xmin + (px - view.offset_x) / view.scale,
     view.ymin + (view.height - view.offset_y - py) / view.scale}
  end

  # Evenly spaced values from `lo` to `hi`, each with its label, about `count` of them.
  # The spacing is 1, 2 or 5 times a power of ten (e.g. 0.2 or 50), so the labels are round numbers.
  # Each value is index * step rather than a running sum, so rounding errors don't add up.
  @spec ticks(float(), float(), integer()) :: list({float(), String.t()})
  defp ticks(lo, hi, count) when hi > lo do
    step = nice_step((hi - lo) / max(count, 2))
    decimals = max(0, -floor(:math.log10(step)))

    for i <- ceil(lo / step)..floor(hi / step)//1 do
      value = i * step
      {value, tick_label(value, decimals)}
    end
  end

  defp ticks(_lo, _hi, _count), do: []

  # The smallest of 1, 2, 5 or 10 times a power of ten that is at least `raw`.
  @spec nice_step(float()) :: float()
  defp nice_step(raw) do
    power = :math.pow(10, floor(:math.log10(raw)))
    Enum.find([1, 2, 5, 10], &(&1 * power >= raw)) * power
  end

  # A tick value with a fixed number of decimals. -0 becomes 0.
  @spec tick_label(float(), non_neg_integer()) :: String.t()
  defp tick_label(value, decimals) when value == 0,
    do: :erlang.float_to_binary(+0.0, decimals: decimals)

  defp tick_label(value, decimals), do: :erlang.float_to_binary(value * 1.0, decimals: decimals)

  # One grid line. The x = 0 and y = 0 lines are drawn darker, as the axes.
  @spec grid_line(T.point_tuple(), T.point_tuple(), boolean(), String.t()) :: iodata()
  defp grid_line({x1, y1}, {x2, y2}, axis?, color) do
    ~s(  <line x1="#{format(x1)}" y1="#{format(y1)}" x2="#{format(x2)}" y2="#{format(y2)}" stroke="#{color}" stroke-width="#{line_width(axis?)}" stroke-opacity="#{line_opacity(axis?)}"/>\n)
  end

  @spec line_width(boolean()) :: number()
  defp line_width(true), do: 1.5
  defp line_width(false), do: 1

  @spec line_opacity(boolean()) :: number()
  defp line_opacity(true), do: 0.9
  defp line_opacity(false), do: 0.3

  @spec axis_font(String.t()) :: String.t()
  defp axis_font(color), do: ~s(font-family="sans-serif" font-size="10" fill="#{color}")

  @spec title(String.t() | nil, keyword()) :: iodata()
  defp title(nil, _opts), do: []

  defp title(text, opts),
    do:
      ~s(  <text x="#{opts[:padding]}" y="#{div(opts[:padding], 2) + 8}" font-family="sans-serif" font-size="16" fill="#212529">#{escape(text)}</text>\n)

  # Makes user text safe to put inside SVG.
  @spec escape(term()) :: String.t()
  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
