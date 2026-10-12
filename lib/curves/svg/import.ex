defmodule Curves.Svg.Import do
  @moduledoc false
  # Reads an SVG document into a Curves.Drawing (see Curves.from_svg/2).
  #
  # The XML is read by a small scanner instead of an XML library: Curves has no dependencies, and
  # Erlang's :xmerl turns every tag and attribute name into an atom, which untrusted input could use
  # to fill the atom table. Here names stay strings. The scanner only ever moves forward through
  # the text (each search starts where the last one ended), so its time grows in step with the
  # size of the input, even for malformed input.
  #
  # Transforms: each element's matrix is its own `transform` times its parent's, and the curves are
  # moved by it with Curves.Spline.Curve.map_points/2 (exact, even for skews and arcs). Polylines
  # simply have their points moved before they are made.
  alias Curves.Drawing
  alias Curves.Drawing.{Shape, Subpath}
  alias Curves.Svg.{PathData, TransformList}
  alias Curves.Types, as: T

  # An open element: its name, its matrix, and whether its content is drawn.
  @typep frame() :: %{name: String.t(), matrix: TransformList.matrix(), drawn: boolean()}

  # The parser's state: the open elements (innermost first), how many are open by name, the
  # drawing so far (nil before the <svg> element), and the options.
  @typep state() :: %{
           stack: list(frame()),
           open: %{String.t() => non_neg_integer()},
           drawing: Drawing.t() | nil,
           opts: keyword()
         }

  @typep event() :: {:open, String.t(), String.t(), boolean()} | {:close, String.t()}

  @shapes %{
    "path" => :path,
    "rect" => :rect,
    "circle" => :circle,
    "ellipse" => :ellipse,
    "line" => :line,
    "polyline" => :polyline,
    "polygon" => :polygon
  }

  # Containers whose content is drawn.
  @groups ["g", "a", "switch"]

  # Elements that are drawn but aren't curves, or that Curves can't follow: listed in :skipped.
  @not_supported ["text", "image", "foreignObject", "use", "svg"]

  # The y axis flipped, for the :flip_y option.
  @flip {1.0, 0.0, 0.0, -1.0, 0.0, 0.0}

  @spec from_svg(String.t(), keyword()) :: Drawing.t()
  def from_svg(svg, opts) when is_binary(svg) do
    svg
    |> scan(0, [])
    |> Enum.reduce(%{stack: [], open: %{}, drawing: nil, opts: opts}, &event/2)
    |> drawing!()
  end

  def from_svg(other, _opts),
    do: raise(ArgumentError, "expected an SVG document as a string, got: #{inspect(other)}")

  # The subpaths of some path data, for Curves.from_svg_path/2. Raises on bad path data.
  @spec from_path(String.t(), keyword()) :: list(Subpath.t())
  def from_path(data, opts) when is_binary(data) do
    case PathData.parse(data) do
      {:ok, subpaths} -> path_subpaths(subpaths, start_matrix(opts))
      {:error, _subpaths, message} -> raise ArgumentError, "invalid path data: #{message}"
    end
  end

  def from_path(other, _opts),
    do: raise(ArgumentError, "expected SVG path data as a string, got: #{inspect(other)}")

  @spec drawing!(state()) :: Drawing.t()
  defp drawing!(%{drawing: nil}),
    do: raise(ArgumentError, "expected an SVG document, but found no <svg> element")

  defp drawing!(%{drawing: drawing}),
    do: %{drawing | shapes: Enum.reverse(drawing.shapes), skipped: Enum.reverse(drawing.skipped)}

  ## Scanning

  # The tags in the document, in order. Text, comments, CDATA, <?...?> and <!...> are skipped.
  @spec scan(binary(), non_neg_integer(), list(event())) :: list(event())
  defp scan(svg, from, acc) do
    case :binary.match(svg, "<", scope: {from, byte_size(svg) - from}) do
      :nomatch -> Enum.reverse(acc)
      {at, 1} -> tag(svg, at, acc)
    end
  end

  # What kind of tag starts at `at`, and where it ends.
  @spec tag(binary(), non_neg_integer(), list(event())) :: list(event())
  defp tag(svg, at, acc) do
    case binary_part(svg, at, min(9, byte_size(svg) - at)) do
      "<!--" <> _ -> skip_past(svg, at + 4, "-->", acc)
      "<![CDATA[" -> skip_past(svg, at + 9, "]]>", acc)
      "<?" <> _ -> skip_past(svg, at + 2, "?>", acc)
      "<!" <> _ -> declaration(svg, at + 2, acc)
      "</" <> _ -> close_tag(svg, at + 2, acc)
      _ -> open_tag(svg, at + 1, acc)
    end
  end

  # Carries on after `ending`, or stops if it never comes.
  @spec skip_past(binary(), non_neg_integer(), binary(), list(event())) :: list(event())
  defp skip_past(svg, from, ending, acc) do
    case find(svg, from, ending) do
      nil -> Enum.reverse(acc)
      at -> scan(svg, at + byte_size(ending), acc)
    end
  end

  # <!DOCTYPE ...>, which may have a [...] section with > inside it.
  @spec declaration(binary(), non_neg_integer(), list(event())) :: list(event())
  defp declaration(svg, from, acc) do
    case :binary.match(svg, [">", "["], scope: {from, byte_size(svg) - from}) do
      {at, 1} when binary_part(svg, at, 1) == "[" ->
        case find(svg, at, "]") do
          nil -> Enum.reverse(acc)
          close -> skip_past(svg, close, ">", acc)
        end

      {at, 1} ->
        scan(svg, at + 1, acc)

      :nomatch ->
        Enum.reverse(acc)
    end
  end

  @spec close_tag(binary(), non_neg_integer(), list(event())) :: list(event())
  defp close_tag(svg, from, acc) do
    case find(svg, from, ">") do
      nil -> Enum.reverse(acc)
      at -> scan(svg, at + 1, [{:close, local(binary_part(svg, from, at - from))} | acc])
    end
  end

  # <name attributes> or <name attributes/>. The end is the first > outside quotes.
  @spec open_tag(binary(), non_neg_integer(), list(event())) :: list(event())
  defp open_tag(svg, from, acc) do
    case tag_end(svg, from) do
      nil ->
        Enum.reverse(acc)

      at ->
        inside = binary_part(svg, from, at - from)
        trimmed = String.trim_trailing(inside)
        self_closing = String.ends_with?(trimmed, "/")
        [name | rest] = String.split(trimmed, ~r/[\s\/]/, parts: 2)
        event = {:open, local(name), Enum.join(rest), self_closing}
        scan(svg, at + 1, [event | acc])
    end
  end

  # Where the tag starting at `from` ends: the next > that isn't inside quotes.
  @spec tag_end(binary(), non_neg_integer()) :: non_neg_integer() | nil
  defp tag_end(svg, from) do
    case :binary.match(svg, [">", "\"", "'"], scope: {from, byte_size(svg) - from}) do
      :nomatch ->
        nil

      {at, 1} ->
        case binary_part(svg, at, 1) do
          ">" -> at
          quote -> after_quote(svg, at + 1, quote)
        end
    end
  end

  @spec after_quote(binary(), non_neg_integer(), binary()) :: non_neg_integer() | nil
  defp after_quote(svg, from, quote) do
    case find(svg, from, quote) do
      nil -> nil
      at -> tag_end(svg, at + 1)
    end
  end

  # Where `pattern` next appears at or after `from`.
  @spec find(binary(), non_neg_integer(), binary()) :: non_neg_integer() | nil
  defp find(svg, from, pattern) do
    case :binary.match(svg, pattern, scope: {from, byte_size(svg) - from}) do
      {at, _length} -> at
      :nomatch -> nil
    end
  end

  # A tag name without its namespace prefix: "svg:path" is "path".
  @spec local(String.t()) :: String.t()
  defp local(name), do: name |> String.trim() |> String.split(":") |> List.last()

  # name="value" and name='value' pairs, with entities like &amp; decoded.
  @spec attributes(String.t()) :: %{String.t() => String.t()}
  defp attributes(text) do
    ~r/([^\s=\/]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/
    |> Regex.scan(text)
    |> Map.new(fn
      [_, name, double] -> {name, decode(double)}
      [_, name, "", single] -> {name, decode(single)}
    end)
  end

  # The five XML entities, and &#nn; and &#xhh; character references.
  @spec decode(String.t()) :: String.t()
  defp decode(value) do
    Regex.replace(~r/&(amp|lt|gt|quot|apos|#\d{1,7}|#x[0-9a-fA-F]{1,6});/, value, fn whole,
                                                                                     name ->
      entity(name, whole)
    end)
  end

  @spec entity(String.t(), String.t()) :: String.t()
  defp entity("amp", _whole), do: "&"
  defp entity("lt", _whole), do: "<"
  defp entity("gt", _whole), do: ">"
  defp entity("quot", _whole), do: "\""
  defp entity("apos", _whole), do: "'"
  defp entity("#x" <> hex, whole), do: character(String.to_integer(hex, 16), whole)
  defp entity("#" <> decimal, whole), do: character(String.to_integer(decimal), whole)

  # A character reference that isn't a real character stays as it was written.
  @spec character(non_neg_integer(), String.t()) :: String.t()
  defp character(code, _whole) when code in 0..0xD7FF or code in 0xE000..0x10FFFF,
    do: <<code::utf8>>

  defp character(_code, whole), do: whole

  ## Elements

  @spec event(event(), state()) :: state()
  defp event({:close, name}, state), do: pop(state, name)

  # The first <svg> is the document: its size, view box and transform.
  defp event({:open, "svg", text, self_closing}, %{drawing: nil} = state) do
    attrs = attributes(text)

    drawing = %Drawing{
      width: attrs["width"],
      height: attrs["height"],
      view_box: view_box(attrs["viewBox"])
    }

    state = %{state | drawing: drawing}
    {matrix, state} = own_matrix(attrs, start_matrix(state.opts), "svg", state)
    push(state, "svg", matrix, matrix != nil, self_closing)
  end

  # Anything before the <svg> element is ignored.
  defp event({:open, _name, _text, _self_closing}, %{drawing: nil} = state), do: state

  defp event({:open, name, _text, self_closing}, %{stack: [%{drawn: false} | _]} = state),
    do: push(state, name, nil, false, self_closing)

  defp event({:open, name, text, self_closing}, %{stack: [parent | _]} = state) do
    element(name, attributes(text), parent.matrix, state, self_closing)
  end

  # Content after the </svg> is ignored.
  defp event({:open, name, _text, self_closing}, state),
    do: push(state, name, nil, false, self_closing)

  @spec element(String.t(), map(), TransformList.matrix(), state(), boolean()) :: state()
  defp element(name, attrs, parent, state, self_closing) when name in @groups do
    {matrix, state} = own_matrix(attrs, parent, name, state)
    push(state, name, matrix, matrix != nil, self_closing)
  end

  defp element(name, attrs, parent, state, self_closing) when is_map_key(@shapes, name) do
    {matrix, state} = own_matrix(attrs, parent, name, state)
    state = shape(Map.fetch!(@shapes, name), attrs, matrix, state)
    push(state, name, nil, false, self_closing)
  end

  defp element(name, attrs, _parent, state, self_closing) when name in @not_supported do
    state |> skip(name, attrs, :not_supported) |> push(name, nil, false, self_closing)
  end

  # Everything else (defs, symbol, clipPath, title, style, ...) isn't drawn, and nor is its content.
  defp element(name, _attrs, _parent, state, self_closing),
    do: push(state, name, nil, false, self_closing)

  # The element's matrix: its own transform after its parent's. nil (and a :skipped entry) when
  # its transform can't be read.
  @spec own_matrix(map(), TransformList.matrix(), String.t(), state()) ::
          {TransformList.matrix() | nil, state()}
  defp own_matrix(attrs, parent, name, state) do
    case TransformList.parse(attrs["transform"]) do
      {:ok, own} -> {TransformList.multiply(parent, own), state}
      {:error, message} -> {nil, skip(state, name, attrs, {:invalid_transform, message})}
    end
  end

  @spec start_matrix(keyword()) :: TransformList.matrix()
  defp start_matrix(opts), do: flip_matrix(Keyword.get(opts, :flip_y, false))

  # Any truthy :flip_y flips, like the other options.
  @spec flip_matrix(term()) :: TransformList.matrix()
  defp flip_matrix(flip) when flip in [false, nil], do: TransformList.identity()
  defp flip_matrix(_flip), do: @flip

  @spec push(state(), String.t(), TransformList.matrix() | nil, boolean(), boolean()) :: state()
  defp push(state, _name, _matrix, _drawn, true = _self_closing), do: state

  defp push(state, name, matrix, drawn, false) do
    frame = %{name: name, matrix: matrix, drawn: drawn}
    %{state | stack: [frame | state.stack], open: Map.update(state.open, name, 1, &(&1 + 1))}
  end

  # Closes `name` and anything left open inside it. A stray closing tag changes nothing. `open`
  # counts the open elements by name, so a stray one is found without searching the stack (which,
  # in a deeply nested document full of stray tags, would take time in proportion to its square).
  @spec pop(state(), String.t()) :: state()
  defp pop(%{open: open} = state, name) when :erlang.map_get(name, open) > 0,
    do: pop_until(state, name)

  defp pop(state, _name), do: state

  @spec pop_until(state(), String.t()) :: state()
  defp pop_until(%{stack: [%{name: top} | stack], open: open} = state, name) do
    state = %{state | stack: stack, open: Map.update!(open, top, &(&1 - 1))}
    pop_more(state, top == name, name)
  end

  @spec pop_more(state(), boolean(), String.t()) :: state()
  defp pop_more(state, true = _found, _name), do: state
  defp pop_more(state, false, name), do: pop_until(state, name)

  @spec skip(state(), String.t(), map(), term()) :: state()
  defp skip(%{drawing: drawing} = state, name, attrs, reason) do
    entry = %{element: name, id: attrs["id"], reason: reason}
    %{state | drawing: %{drawing | skipped: [entry | drawing.skipped]}}
  end

  @spec view_box(String.t() | nil) :: {float(), float(), float(), float()} | nil
  defp view_box(nil), do: nil

  defp view_box(text) do
    case PathData.numbers(text) do
      {[x, y, w, h], nil} -> {x, y, w, h}
      _ -> nil
    end
  end

  ## Shapes

  # A shape with an unreadable transform was already skipped.
  @spec shape(Shape.element(), map(), TransformList.matrix() | nil, state()) :: state()
  defp shape(_kind, _attrs, nil, state), do: state

  defp shape(kind, attrs, matrix, state) do
    case subpaths(kind, attrs, matrix) do
      {:ok, subpaths} ->
        add(state, kind, attrs, subpaths)

      {:partial, subpaths, reason} ->
        state |> add(kind, attrs, subpaths) |> skip(name(kind), attrs, reason)

      {:skip, reason} ->
        skip(state, name(kind), attrs, reason)
    end
  end

  @spec name(Shape.element()) :: String.t()
  defp name(kind), do: Atom.to_string(kind)

  # A shape with no subpaths at all (e.g. path data that fails straight away) isn't added.
  @spec add(state(), Shape.element(), map(), list(Subpath.t())) :: state()
  defp add(state, _kind, _attrs, []), do: state

  defp add(%{drawing: drawing} = state, kind, attrs, subpaths) do
    shape = %Shape{element: kind, id: attrs["id"], subpaths: subpaths, attributes: attrs}
    %{state | drawing: %{drawing | shapes: [shape | drawing.shapes]}}
  end

  @typep result() ::
           {:ok, list(Subpath.t())}
           | {:partial, list(Subpath.t()), term()}
           | {:skip, term()}

  @spec subpaths(Shape.element(), map(), TransformList.matrix()) :: result()
  defp subpaths(:path, attrs, matrix) do
    case PathData.parse(attrs["d"] || "") do
      {:ok, subpaths} ->
        {:ok, path_subpaths(subpaths, matrix)}

      {:error, subpaths, message} ->
        {:partial, path_subpaths(subpaths, matrix), {:invalid_path, message}}
    end
  end

  defp subpaths(:line, attrs, matrix) do
    with {:ok, [x1, y1, x2, y2]} <- lengths(attrs, ["x1", "y1", "x2", "y2"]) do
      {:ok, [polyline([{x1, y1}, {x2, y2}], false, matrix)]}
    end
  end

  defp subpaths(kind, attrs, matrix) when kind in [:polyline, :polygon] do
    {numbers, error} = PathData.numbers(attrs["points"] || "")
    points = numbers |> Enum.chunk_every(2, 2, :discard) |> Enum.map(&List.to_tuple/1)
    poly_result(kind, points, matrix, error || odd_error(rem(length(numbers), 2)))
  end

  defp subpaths(:circle, attrs, matrix) do
    with {:ok, [cx, cy, r]} <- lengths(attrs, ["cx", "cy", "r"]),
         :ok <- size(r, "r") do
      {:ok, [ellipse({cx, cy}, r, r, matrix)]}
    end
  end

  defp subpaths(:ellipse, attrs, matrix) do
    # A missing rx or ry is the same as the other one (SVG 2's "auto").
    attrs = attrs |> Map.put_new("rx", attrs["ry"]) |> Map.put_new("ry", attrs["rx"])

    with {:ok, [cx, cy, rx, ry]} <- lengths(attrs, ["cx", "cy", "rx", "ry"]),
         :ok <- size(rx, "rx"),
         :ok <- size(ry, "ry") do
      {:ok, [ellipse({cx, cy}, rx, ry, matrix)]}
    end
  end

  defp subpaths(:rect, attrs, matrix) do
    with {:ok, [x, y, w, h]} <- lengths(attrs, ["x", "y", "width", "height"]),
         :ok <- size(w, "width"),
         :ok <- size(h, "height"),
         {:ok, rx, ry} <- corner_radii(attrs, w, h) do
      points = rect_points(x, y, w, h, rx, ry)
      {:ok, [bake(%Subpath{curve: Curves.define_bezier_spline(points), closed: true}, matrix)]}
    end
  end

  # SVG draws the pairs before a missing last coordinate, and counts it as an error.
  @spec odd_error(0 | 1) :: String.t() | nil
  defp odd_error(0), do: nil
  defp odd_error(1), do: "an odd number of coordinates"

  # The points of a polyline or polygon, with the error that stopped them, if any.
  @spec poly_result(Shape.element(), T.point_list(), TransformList.matrix(), String.t() | nil) ::
          result()
  defp poly_result(_kind, [], _matrix, _error), do: {:skip, :empty}
  defp poly_result(:polyline, points, matrix, nil), do: {:ok, [polyline(points, false, matrix)]}

  defp poly_result(:polygon, [first | _] = points, matrix, nil),
    do: {:ok, [polyline(points ++ [first], true, matrix)]}

  defp poly_result(kind, points, matrix, error) do
    {:ok, subpaths} = poly_result(kind, points, matrix, nil)
    {:partial, subpaths, {:invalid, "points: #{error}"}}
  end

  @spec path_subpaths(list(PathData.subpath()), TransformList.matrix()) :: list(Subpath.t())
  defp path_subpaths(subpaths, matrix) do
    Enum.map(subpaths, fn {points, closed} ->
      bake(%Subpath{curve: Curves.define_bezier_spline(points), closed: closed}, matrix)
    end)
  end

  # Polylines are made from points already moved by the matrix.
  @spec polyline(T.point_list(), boolean(), TransformList.matrix()) :: Subpath.t()
  defp polyline(points, closed, matrix) do
    curve = points |> Enum.map(&TransformList.move(matrix, &1)) |> Curves.define_polyline()
    %Subpath{curve: curve, closed: closed}
  end

  @spec ellipse(T.point_tuple(), float(), float(), TransformList.matrix()) :: Subpath.t()
  defp ellipse(center, rx, ry, matrix),
    do: bake(%Subpath{curve: Curves.define_ellipse(center, {rx, ry}), closed: true}, matrix)

  # Moves a spline by the matrix (nothing to do for the identity).
  @spec bake(Subpath.t(), TransformList.matrix()) :: Subpath.t()
  # (== in a guard, so -0.0 counts as 0.0, which a pattern wouldn't.)
  defp bake(subpath, matrix) when matrix == {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}, do: subpath

  defp bake(%Subpath{curve: curve} = subpath, matrix),
    do: %{subpath | curve: Curves.Spline.Curve.map_points(curve, &TransformList.move(matrix, &1))}

  # A rectangle as SVG draws it: clockwise on screen from the top left corner (after its rounding),
  # with an arc at each rounded corner.
  @spec rect_points(float(), float(), float(), float(), float(), float()) :: list(list())
  defp rect_points(x, y, w, h, rx, ry) when rx == 0 or ry == 0,
    do: [[{x, y}], [{x + w, y}], [{x + w, y + h}], [{x, y + h}], [{x, y}]]

  defp rect_points(x, y, w, h, rx, ry) do
    arc = {:arc, rx, ry, 0, false, true}

    [
      [{x + rx, y}],
      [{x + w - rx, y}, arc],
      [{x + w, y + ry}],
      [{x + w, y + h - ry}, arc],
      [{x + w - rx, y + h}],
      [{x + rx, y + h}, arc],
      [{x, y + h - ry}],
      [{x, y + ry}, arc],
      [{x + rx, y}]
    ]
    |> drop_empty_lines()
  end

  # When the corners are as big as the side, its straight part has no length: it is left out, so
  # the curve has no segments that stay still.
  @spec drop_empty_lines(list(list())) :: list(list())
  defp drop_empty_lines([[knot], [knot | _] = next | rest]), do: drop_empty_lines([next | rest])
  defp drop_empty_lines([point | rest]), do: [point | drop_empty_lines(rest)]
  defp drop_empty_lines([]), do: []

  # A rectangle's corner radii, by SVG's rules: a missing one is the same as the other, both
  # missing are 0, and neither can be more than half the side.
  @spec corner_radii(map(), float(), float()) :: {:ok, float(), float()} | {:skip, term()}
  defp corner_radii(attrs, w, h) do
    attrs = attrs |> Map.put_new("rx", attrs["ry"]) |> Map.put_new("ry", attrs["rx"])

    with {:ok, [rx, ry]} <- lengths(attrs, ["rx", "ry"]),
         :ok <- not_negative(rx, "rx"),
         :ok <- not_negative(ry, "ry") do
      {:ok, min(rx, w / 2), min(ry, h / 2)}
    end
  end

  # A size SVG draws: more than 0. A size of 0 is :empty, and below 0 is an error.
  @spec size(float(), String.t()) :: :ok | {:skip, term()}
  defp size(value, _name) when value > 0, do: :ok
  defp size(value, _name) when value == 0, do: {:skip, :empty}
  defp size(value, name), do: {:skip, {:invalid, "#{name} can't be negative, got: #{value}"}}

  @spec not_negative(float(), String.t()) :: :ok | {:skip, term()}
  defp not_negative(value, name) when value < 0,
    do: {:skip, {:invalid, "#{name} can't be negative, got: #{value}"}}

  defp not_negative(_value, _name), do: :ok

  # The attributes as numbers. A missing one is 0. Only plain numbers and px can be read.
  @spec lengths(map(), list(String.t())) :: {:ok, list(float())} | {:skip, term()}
  defp lengths(attrs, names) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, acc} ->
      case length_value(attrs[name]) do
        {:ok, value} -> {:cont, {:ok, acc ++ [value]}}
        {:skip, reason} -> {:halt, {:skip, reason}}
      end
    end)
  end

  @spec length_value(String.t() | nil) :: {:ok, float()} | {:skip, term()}
  defp length_value(nil), do: {:ok, 0.0}

  defp length_value(text) do
    case PathData.number(text) do
      {:ok, value, rest} -> unit(value, String.trim(rest), text)
      {:error, message} -> {:skip, {:invalid, message}}
    end
  end

  @spec unit(float(), String.t(), String.t()) :: {:ok, float()} | {:skip, term()}
  defp unit(value, unit, _text) when unit in ["", "px"], do: {:ok, value}
  defp unit(_value, _unit, text), do: {:skip, {:unsupported_unit, String.trim(text)}}
end
