defmodule Curves.Svg do
  @moduledoc ~s"""
  Draws a Bezier or Spline curve as an SVG image, using only Elixir.

  The curve is sampled `samples` times from start to end, and the points are joined with a line.
  The curve's own points are drawn as dots, and the image is scaled to fit while keeping the curve's shape.

  ```elixir
  curve = Curves.define_b_spline([{0, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 2}, {1, 2}])
  Curves.Svg.save!(curve, 300, "b_spline.svg", title: "B-Spline")
  ```

  ## Options

  | `key` | `default` | `description` |
  | --- | --- | --- |
  | `:width` | `600` | Image width in pixels. |
  | `:height` | `600` | Image height in pixels. |
  | `:padding` | `40` | Empty space around the curve, in pixels. |
  | `:background` | `"#ffffff"` | Background colour. `nil` leaves it transparent. |
  | `:stroke` | `"#1c7ed6"` | Colour of the curve. |
  | `:stroke_width` | `3` | Thickness of the curve. |
  | `:show_points` | `true` | Draw the curve's own points as dots. |
  | `:point_color` | `"#d9480f"` | Colour of the dots. |
  | `:point_radius` | `5` | Size of the dots. |
  | `:show_polygon` | `false` | Draw a dashed line joining the curve's own points in order. |
  | `:polygon_color` | `"#adb5bd"` | Colour of that dashed line. |
  | `:title` | `nil` | Text drawn in the top-left corner. |
  | `:solve_opts` | `[]` | Options passed to `Curves.take!/3` and `Curves.solve!/3`. |

  The dots are the points the curve stores. For most curves these are the points you defined it with,
  but B-splines store the control points they generate from yours.

  If `:solve_opts` turns on `:force_percent`, the curve is drawn in 0..1 but its points are not,
  so set `show_points: false` (and leave `show_polygon: false`).
  """
  alias Curves.Bezier.Curve, as: Bezier
  alias Curves.Spline.Curve, as: Spline
  alias Curves.Utils.Types, as: T

  @defaults [
    width: 600,
    height: 600,
    padding: 40,
    background: "#ffffff",
    stroke: "#1c7ed6",
    stroke_width: 3,
    show_points: true,
    point_color: "#d9480f",
    point_radius: 5,
    show_polygon: false,
    polygon_color: "#adb5bd",
    title: nil,
    solve_opts: []
  ]

  @doc ~s"""
  Builds the SVG for a curve and returns it as a string.

  `samples` is how many points are taken along the curve, not counting the start.
  More samples give a smoother line. See the module docs for `opts`.

  ## Examples
      iex> curve = Curves.define_bezier(:linear)
      iex> svg = Curves.Svg.render(curve, 2, width: 100, height: 100, padding: 0, show_points: false)
      iex> String.starts_with?(svg, "<svg")
      true
      iex> svg =~ ~s(points="0.00,100.00 50.00,50.00 100.00,0.00")
      true
  """
  @spec render(T.curve_struct(), pos_integer(), keyword()) :: String.t()
  def render(curve, samples, opts \\ []) when is_integer(samples) and samples > 0 do
    opts = Keyword.merge(@defaults, opts)
    line = sample(curve, samples, opts[:solve_opts])
    points = control_points(curve)
    to_pixels = scaler(line ++ shown_points(points, opts), opts)

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{opts[:width]}" height="#{opts[:height]}" viewBox="0 0 #{opts[:width]} #{opts[:height]}">\n),
      background(opts[:background]),
      polygon(opts[:show_polygon], points, to_pixels, opts),
      ~s(  <polyline points="#{polyline(line, to_pixels)}" fill="none" stroke="#{escape(opts[:stroke])}" stroke-width="#{opts[:stroke_width]}" stroke-linejoin="round" stroke-linecap="round"/>\n),
      dots(opts[:show_points], points, to_pixels, opts),
      title(opts[:title], opts),
      "</svg>\n"
    ]
    |> IO.iodata_to_binary()
  end

  @doc ~s"""
  Builds the SVG for a curve with `render/3` and writes it to `path`.
  Returns `path`, and raises if the file can't be written.

  ## Examples
      iex> path = Path.join(System.tmp_dir!(), "curves_svg_doctest.svg")
      iex> curve = Curves.define_bezier(:ease_in_out_cubic)
      iex> Curves.Svg.save!(curve, 50, path)
      iex> File.read!(path) |> String.starts_with?("<svg")
      true
  """
  @spec save!(T.curve_struct(), pos_integer(), Path.t(), keyword()) :: Path.t()
  def save!(curve, samples, path, opts \\ []) do
    File.write!(path, render(curve, samples, opts))
    path
  end

  # The start of the curve plus `samples` evenly spaced points. take!/3 skips the start, so it is added here.
  @spec sample(T.curve_struct(), pos_integer(), T.opts()) :: T.point_list()
  defp sample(curve, samples, solve_opts),
    do: [Curves.solve!(curve, 0.0, solve_opts) | Curves.take!(curve, samples, solve_opts)]

  # The curve's own points that will be drawn, so the image is only sized around what is visible.
  @spec shown_points(T.point_list(), keyword()) :: T.point_list()
  defp shown_points(points, opts),
    do: points_if_shown(opts[:show_points] or opts[:show_polygon], points)

  @spec points_if_shown(boolean(), T.point_list()) :: T.point_list()
  defp points_if_shown(false, _points), do: []
  defp points_if_shown(_shown, points), do: points

  # The curve's own points as {x, y} tuples, moved, scaled and rotated like the curve.
  # Repeated neighbours (B-splines store some points twice) are drawn once.
  @spec control_points(T.curve_struct()) :: T.point_list()
  defp control_points(%Bezier{} = curve) do
    %{points: points} = Curves.Transform.apply_all_transformations(curve)
    to_tuples(points)
  end

  defp control_points(%Spline{points: points} = curve) do
    curve
    |> Curves.Transform.apply_all_transformations()
    |> Curves.Transform.transform_points(points)
    |> to_tuples()
  end

  # {2, n} tensor to a list of n {x, y} tuples.
  @spec to_tuples(T.points()) :: T.point_list()
  defp to_tuples(points) do
    [xs, ys] = Nx.to_list(points)
    Enum.zip(xs, ys) |> Enum.dedup()
  end

  # Returns a function that maps a curve point to an SVG pixel. The scale is the same on
  # both axes so the shape isn't stretched, the drawing is centred, and y is flipped
  # because SVG's y grows downwards.
  @spec scaler(T.point_list(), keyword()) :: (T.point_tuple() -> T.point_tuple())
  defp scaler(all_points, opts) do
    {xmin, xmax} = all_points |> Enum.map(&elem(&1, 0)) |> Enum.min_max()
    {ymin, ymax} = all_points |> Enum.map(&elem(&1, 1)) |> Enum.min_max()
    inner_w = opts[:width] - 2 * opts[:padding]
    inner_h = opts[:height] - 2 * opts[:padding]
    scale = min(fit(inner_w, xmax - xmin), fit(inner_h, ymax - ymin))
    offset_x = opts[:padding] + (inner_w - (xmax - xmin) * scale) / 2
    offset_y = opts[:padding] + (inner_h - (ymax - ymin) * scale) / 2

    fn {x, y} ->
      {offset_x + (x - xmin) * scale, opts[:height] - offset_y - (y - ymin) * scale}
    end
  end

  # Pixels per unit along one axis. A flat axis (span 0) doesn't limit the scale.
  @spec fit(number(), number()) :: number()
  defp fit(_pixels, span) when span == 0, do: :infinity
  defp fit(pixels, span), do: pixels / span

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

  @spec polygon(boolean(), T.point_list(), (T.point_tuple() -> T.point_tuple()), keyword()) ::
          iodata()
  defp polygon(false, _points, _to_pixels, _opts), do: []

  defp polygon(_show, points, to_pixels, opts),
    do:
      ~s(  <polyline points="#{polyline(points, to_pixels)}" fill="none" stroke="#{escape(opts[:polygon_color])}" stroke-width="1.5" stroke-dasharray="6 4"/>\n)

  @spec dots(boolean(), T.point_list(), (T.point_tuple() -> T.point_tuple()), keyword()) ::
          iodata()
  defp dots(false, _points, _to_pixels, _opts), do: []

  defp dots(_show, points, to_pixels, opts) do
    for point <- points do
      {x, y} = to_pixels.(point)

      ~s(  <circle cx="#{format(x)}" cy="#{format(y)}" r="#{opts[:point_radius]}" fill="#{escape(opts[:point_color])}"/>\n)
    end
  end

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
