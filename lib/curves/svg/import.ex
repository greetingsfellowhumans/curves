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
  # The drawing keeps the document's structure: shapes become curves, groups stay groups, and
  # everything else (text, <defs>, <style>, ...) is kept as markup (Curves.Drawing.Raw), cleaned of
  # scripts, so that Curves.Svg can draw it again as it was.
  #
  # Transforms: each element's matrix is its own `transform` times its parent's. The curves are moved
  # by it with Curves.Spline.Curve.map_points/2 (exact, even for skews and arcs); polylines simply
  # have their points moved before they are made. The shape keeps the matrix too.
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Raw, Shape, Subpath}
  alias Curves.Svg.{PathData, TransformList}
  alias Curves.Types, as: T

  # An open element. `kind` says what it becomes when it closes: the drawing (:root), a Group, a Raw
  # (its markup starts at `start`), or nothing (:ignore, for content that isn't drawn).
  @typep frame() :: %{
           name: String.t(),
           kind: :root | :group | :raw | :ignore,
           matrix: TransformList.matrix() | nil,
           start: non_neg_integer(),
           node: Group.t() | String.t() | nil,
           children: list(Drawing.child())
         }

  # The parser's state: the source, the open elements (innermost first), how many are open by name,
  # the drawing so far (nil before the <svg> element), the matrix of the shape being read, and the
  # options.
  @typep state() :: %{
           svg: binary(),
           stack: list(frame()),
           open: %{String.t() => non_neg_integer()},
           drawing: Drawing.t() | nil,
           matrix: TransformList.matrix() | nil,
           opts: keyword()
         }

  # A tag: its name without any namespace prefix, its name as written, its attributes' text,
  # whether it closes itself, and where it starts and ends in the source.
  # Whether a tag closes itself, and where it starts and ends in the source.
  @typep tag() :: {boolean(), non_neg_integer(), non_neg_integer()}

  @typep event() ::
           {:open, String.t(), String.t(), String.t(), boolean(), non_neg_integer(),
            non_neg_integer()}
           | {:close, String.t(), non_neg_integer(), non_neg_integer()}

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

  # Elements that are drawn but aren't curves, or that Curves can't follow: listed in :skipped, and
  # kept as markup.
  @not_curves ["text", "image", "use", "svg"]

  # Never kept, so a drawing drawn again can't run anything: listed in :skipped.
  @unsafe ["script", "foreignObject"]

  # The y axis flipped, for the :flip_y option.
  @flip {1.0, 0.0, 0.0, -1.0, 0.0, 0.0}

  @spec from_svg(String.t(), keyword()) :: Drawing.t()
  def from_svg(svg, opts) when is_binary(svg) do
    state = %{svg: svg, stack: [], open: %{}, drawing: nil, matrix: nil, opts: opts}

    svg
    |> scan(0, [])
    |> Enum.reduce(state, &event/2)
    |> close_all()
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

  defp drawing!(%{drawing: drawing}), do: %{drawing | skipped: Enum.reverse(drawing.skipped)}

  # Closes whatever is still open at the end of the document.
  @spec close_all(state()) :: state()
  defp close_all(%{stack: []} = state), do: state
  defp close_all(state), do: state |> close_top(byte_size(state.svg)) |> close_all()

  ## Scanning

  # The document's tags, with their attributes, for checking output in tests.
  @doc false
  @spec tags(binary()) ::
          list(
            {:open, String.t(), list({String.t(), String.t()}), boolean()}
            | {:close, String.t()}
          )
  def tags(svg) do
    svg
    |> scan(0, [])
    |> Enum.map(fn
      {:open, name, _raw, text, self_closing, _start, _stop} ->
        {:open, name, attribute_list(text), self_closing}

      {:close, name, _start, _stop} ->
        {:close, name}
    end)
  end

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
      "</" <> _ -> close_tag(svg, at, acc)
      _ -> open_tag(svg, at, acc)
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
  defp close_tag(svg, start, acc) do
    case find(svg, start + 2, ">") do
      nil ->
        Enum.reverse(acc)

      at ->
        name = local(binary_part(svg, start + 2, at - start - 2))
        scan(svg, at + 1, [{:close, name, start, at + 1} | acc])
    end
  end

  # <name attributes> or <name attributes/>. The end is the first > outside quotes.
  @spec open_tag(binary(), non_neg_integer(), list(event())) :: list(event())
  defp open_tag(svg, start, acc) do
    case tag_end(svg, start + 1) do
      nil ->
        Enum.reverse(acc)

      at ->
        inside = binary_part(svg, start + 1, at - start - 1)
        trimmed = String.trim_trailing(inside)
        self_closing = String.ends_with?(trimmed, "/")
        [name | rest] = String.split(trimmed, ~r/[\s\/]/, parts: 2)
        event = {:open, local(name), name, Enum.join(rest), self_closing, start, at + 1}
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

  # name="value" and name='value' pairs, in order, with entities like &amp; decoded.
  @spec attribute_list(String.t()) :: list({String.t(), String.t()})
  defp attribute_list(text) do
    ~r/([^\s=\/]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/
    |> Regex.scan(text)
    |> Enum.map(fn
      [_, name, double] -> {name, decode(double)}
      [_, name, "", single] -> {name, decode(single)}
    end)
  end

  @spec attributes(String.t()) :: %{String.t() => String.t()}
  defp attributes(text), do: text |> attribute_list() |> Map.new()

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

  # A character reference to a character XML doesn't allow (like &#0;) stays as it was written.
  @spec character(non_neg_integer(), String.t()) :: String.t()
  defp character(code, _whole)
       when code in [0x9, 0xA, 0xD] or code in 0x20..0xD7FF or code in 0xE000..0xFFFD or
              code in 0x10000..0x10FFFF,
       do: <<code::utf8>>

  defp character(_code, whole), do: whole

  ## Keeping markup safe

  # Animations that can change an attribute while the picture is shown, so they could turn a link
  # into a script (`<set attributeName="href" to="javascript:...">`).
  @animations ["set", "animate", "animateTransform", "animateMotion", "animateColor"]

  # An element or attribute name as XML allows, without anything that could break the markup.
  @name ~r/\A[A-Za-z_][A-Za-z0-9_.:\-]*\z/

  # Whether an attribute could run code, or break the markup: event handlers (onclick, onload,
  # ...), javascript: and vbscript: links (browsers ignore spaces, tabs and newlines in them, so
  # those are ignored here too), and names that aren't valid.
  @doc false
  @spec unsafe_attribute?({String.t(), String.t()}) :: boolean()
  def unsafe_attribute?({name, value}) do
    link = value |> String.replace(~r/[\x00-\x20\x7f]+/, "") |> String.downcase()

    not Regex.match?(@name, name) or String.starts_with?(String.downcase(name), "on") or
      String.starts_with?(link, ["javascript:", "vbscript:"])
  end

  # Whether a whole element (and everything in it) is taken out of kept markup.
  @spec unsafe_element?(String.t(), String.t(), String.t()) :: boolean()
  defp unsafe_element?(name, raw, text) do
    name in @unsafe or not Regex.match?(@name, raw) or
      (name in @animations and animates_unsafe?(attributes(text)["attributeName"]))
  end

  # Whether an animation changes an event handler or a link.
  @spec animates_unsafe?(String.t() | nil) :: boolean()
  defp animates_unsafe?(nil), do: false

  defp animates_unsafe?(attribute) do
    attribute = attribute |> String.trim() |> String.downcase()
    String.starts_with?(attribute, "on") or attribute in ["href", "xlink:href"]
  end

  # The markup of a kept element, made safe and well formed: <script> and <foreignObject> (and
  # everything in them), animations of links and event handlers, event attributes, javascript:
  # links and invalid names are taken out; tags left open are closed, stray closing tags are left
  # out, and so is an unfinished tag at the end. Text, comments and CDATA between the tags are
  # copied as they were. It is scanned again on its own, which is quick.
  @spec clean(binary()) :: binary()
  defp clean(markup) do
    acc = %{out: [], cursor: 0, removing: 0, open: [], counts: %{}}

    %{out: out, cursor: cursor, open: open} =
      markup
      |> scan(0, [])
      |> Enum.reduce(acc, &clean_event(&1, &2, markup))

    IO.iodata_to_binary([out, finished_text(tail(markup, cursor)), Enum.map(open, &closing/1)])
  end

  # The rest of the markup after `cursor`.
  @spec tail(binary(), non_neg_integer()) :: binary()
  defp tail(markup, cursor), do: binary_part(markup, cursor, byte_size(markup) - cursor)

  # The text after the last tag, up to anything unfinished (scanning stops at a tag, comment or
  # CDATA that never ends).
  @spec finished_text(binary()) :: binary()
  defp finished_text(text), do: text |> String.split("<", parts: 2) |> hd()

  @spec closing({String.t(), String.t()}) :: iodata()
  defp closing({_name, raw}), do: ["</", raw, ">"]

  @typep clean_acc() :: %{
           out: iodata(),
           cursor: non_neg_integer(),
           removing: non_neg_integer(),
           open: list({String.t(), String.t()}),
           counts: %{String.t() => non_neg_integer()}
         }

  # `removing` is how deep inside a removed element the tag is (0 when not); `open` is the kept
  # elements still open, innermost first, as {name, name as written}, and `counts` how many are
  # open by name, so a stray closing tag is found without searching `open`.
  @spec clean_event(event(), clean_acc(), binary()) :: clean_acc()
  defp clean_event(
         {:open, _name, _raw, _text, self_closing, _start, stop},
         %{removing: depth} = acc,
         _markup
       )
       when depth > 0,
       do: %{acc | cursor: stop, removing: depth + removed_depth(self_closing)}

  defp clean_event({:close, _name, _start, stop}, %{removing: depth} = acc, _markup)
       when depth > 0,
       do: %{acc | cursor: stop, removing: depth - 1}

  defp clean_event({:open, name, raw, text, self_closing, start, stop}, acc, markup) do
    acc = copy_text(acc, markup, start)
    open_tag_clean(acc, {name, raw, text, self_closing, stop}, unsafe_element?(name, raw, text))
  end

  defp clean_event({:close, name, start, stop}, acc, markup) do
    acc = copy_text(acc, markup, start)
    close_clean(%{acc | cursor: stop}, name, Map.get(acc.counts, name, 0))
  end

  @spec open_tag_clean(clean_acc(), tuple(), boolean()) :: clean_acc()
  defp open_tag_clean(acc, {_name, _raw, _text, self_closing, stop}, true = _unsafe),
    do: %{acc | cursor: stop, removing: removed_depth(self_closing)}

  defp open_tag_clean(acc, {_name, raw, text, true, stop}, false),
    do: %{acc | out: [acc.out | clean_tag(raw, text, true)], cursor: stop}

  defp open_tag_clean(acc, {name, raw, text, false, stop}, false) do
    %{
      acc
      | out: [acc.out | clean_tag(raw, text, false)],
        cursor: stop,
        open: [{name, raw} | acc.open],
        counts: Map.update(acc.counts, name, 1, &(&1 + 1))
    }
  end

  # A closing tag closes its element and anything left open inside it; a stray one (none of that
  # name is open) is left out.
  @spec close_clean(clean_acc(), String.t(), non_neg_integer()) :: clean_acc()
  defp close_clean(acc, _name, 0 = _open), do: acc
  defp close_clean(acc, name, _open), do: close_until(acc, name)

  # Each element closed here is closed only once, so this takes time in step with the markup.
  @spec close_until(clean_acc(), String.t()) :: clean_acc()
  defp close_until(%{open: [{top, _raw} = element | open]} = acc, name) do
    acc = %{
      acc
      | out: [acc.out | closing(element)],
        open: open,
        counts: Map.update!(acc.counts, top, &(&1 - 1))
    }

    close_more(acc, top == name, name)
  end

  @spec close_more(clean_acc(), boolean(), String.t()) :: clean_acc()
  defp close_more(acc, true = _found, _name), do: acc
  defp close_more(acc, false, name), do: close_until(acc, name)

  # Copies the text between the last tag and the one starting at `start`.
  @spec copy_text(clean_acc(), binary(), non_neg_integer()) :: clean_acc()
  defp copy_text(%{cursor: cursor} = acc, markup, start),
    do: %{acc | out: [acc.out | binary_part(markup, cursor, start - cursor)], cursor: start}

  # How deep inside a removed element the next tag is: a self-closing one has nothing inside.
  @spec removed_depth(boolean()) :: 0 | 1
  defp removed_depth(true = _self_closing), do: 0
  defp removed_depth(false), do: 1

  @spec clean_tag(String.t(), String.t(), boolean()) :: iodata()
  defp clean_tag(name, text, self_closing) do
    attributes =
      text
      |> attribute_list()
      |> Enum.reject(&unsafe_attribute?/1)
      |> Enum.map(fn {key, value} -> [" ", key, "=\"", escape(value), "\""] end)

    ["<", name, attributes, tag_close(self_closing)]
  end

  @spec tag_close(boolean()) :: String.t()
  defp tag_close(true = _self_closing), do: "/>"
  defp tag_close(false), do: ">"

  # Makes text safe to put inside an attribute's quotes. Tabs and line breaks are written as
  # character references too, since reading XML turns them into spaces in an attribute.
  @doc false
  @spec escape(String.t()) :: String.t()
  def escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("\t", "&#9;")
    |> String.replace("\n", "&#10;")
    |> String.replace("\r", "&#13;")
  end

  ## Elements

  @spec event(event(), state()) :: state()
  defp event({:close, name, start, stop}, state), do: pop(state, name, start, stop)

  # The first <svg> is the document: its size, view box and transform.
  defp event({:open, "svg", _raw, text, self_closing, start, _stop}, %{drawing: nil} = state) do
    attrs = attributes(text)

    {matrix, state} =
      own_matrix(attrs, start_matrix(state.opts), "svg", start_drawing(state, attrs))

    root = %{
      name: "svg",
      kind: kind(matrix, :root),
      matrix: matrix,
      start: start,
      node: nil,
      children: []
    }

    state = %{state | stack: [root], open: %{"svg" => 1}}
    close_if_self_closing(state, self_closing, start)
  end

  # Anything before the <svg> element is ignored.
  defp event({:open, _name, _raw, _text, _self_closing, _start, _stop}, %{drawing: nil} = state),
    do: state

  # Inside content that isn't drawn, or inside kept markup, tags only need to be matched up.
  defp event(
         {:open, name, _raw, _text, self_closing, start, _stop},
         %{stack: [%{kind: kind} | _]} = state
       )
       when kind in [:ignore, :raw],
       do: push(state, name, :ignore, nil, start, nil, self_closing)

  defp event(
         {:open, name, _raw, text, self_closing, start, stop},
         %{stack: [parent | _]} = state
       ),
       do: element(name, attributes(text), parent.matrix, state, {self_closing, start, stop})

  # Content after the </svg> is ignored.
  defp event({:open, _name, _raw, _text, _self_closing, _start, _stop}, state), do: state

  @spec start_drawing(state(), map()) :: state()
  defp start_drawing(state, attrs) do
    drawing = %Drawing{
      width: attrs["width"],
      height: attrs["height"],
      view_box: attrs["viewBox"] |> view_box() |> flip_view_box(flip?(state.opts)),
      attributes: attrs
    }

    %{state | drawing: drawing}
  end

  @spec element(
          String.t(),
          map(),
          TransformList.matrix(),
          state(),
          tag()
        ) ::
          state()
  defp element(name, attrs, parent, state, tag) when name in @groups do
    {matrix, state} = own_matrix(attrs, parent, name, state)
    group = %Group{element: name, id: attrs["id"], attributes: Map.delete(attrs, "transform")}
    group_or_markup(state, name, matrix, parent, group, tag)
  end

  defp element(name, attrs, parent, state, tag) when is_map_key(@shapes, name) do
    {matrix, state} = own_matrix(attrs, parent, name, state)
    {state, keep} = shape(Map.fetch!(@shapes, name), attrs, matrix, state)
    after_shape(state, keep, name, parent, tag)
  end

  defp element(name, attrs, _parent, state, {self_closing, start, _stop}) when name in @unsafe do
    state
    |> skip(name, attrs, :unsafe, :no)
    |> push(name, :ignore, nil, start, nil, self_closing)
  end

  # Everything else is kept as markup: text, images and so on are also listed in :skipped, while
  # defs, style, title and the like (which aren't drawn themselves) are only kept.
  defp element(name, attrs, parent, state, {self_closing, start, stop}) do
    state
    |> skip_if_not_curves(name, attrs)
    |> push(name, :raw, parent, start, nil, false)
    |> close_if_self_closing(self_closing, stop)
  end

  @spec skip_if_not_curves(state(), String.t(), map()) :: state()
  defp skip_if_not_curves(state, name, attrs) when name in @not_curves,
    do: skip(state, name, attrs, :not_curves, :as_markup)

  defp skip_if_not_curves(state, _name, _attrs), do: state

  # A group whose transform couldn't be read (nil) is kept as markup, so it is drawn again however
  # the SVG's viewer draws it.
  @spec group_or_markup(
          state(),
          String.t(),
          TransformList.matrix() | nil,
          TransformList.matrix(),
          Group.t(),
          tag()
        ) ::
          state()
  defp group_or_markup(state, name, nil, parent, _group, tag),
    do: keep_markup(state, name, parent, tag)

  defp group_or_markup(state, name, matrix, _parent, group, {self_closing, start, _stop}),
    do: push(state, name, :group, matrix, start, group, self_closing)

  # A shape that couldn't be read is kept as markup when the SVG's viewer would still draw it (see
  # shape/4); anything inside a shape (like a <title>) is ignored.
  @spec after_shape(state(), :raw | :ignore, String.t(), TransformList.matrix(), tag()) :: state()
  defp after_shape(state, :raw, name, parent, tag), do: keep_markup(state, name, parent, tag)

  defp after_shape(state, :ignore, name, _parent, {self_closing, start, _stop}),
    do: push(state, name, :ignore, nil, start, nil, self_closing)

  # Keeps the element as markup, with its parent's matrix.
  @spec keep_markup(state(), String.t(), TransformList.matrix(), tag()) :: state()
  defp keep_markup(state, name, parent, {self_closing, start, stop}) do
    state
    |> push(name, :raw, parent, start, nil, false)
    |> close_if_self_closing(self_closing, stop)
  end

  # The root <svg> with a transform that couldn't be read (nil) draws nothing.
  @spec kind(TransformList.matrix() | nil, :root) :: :root | :ignore
  defp kind(nil, _kind), do: :ignore
  defp kind(_matrix, kind), do: kind

  # A self-closing element closes straight away, ending at `stop`.
  @spec close_if_self_closing(state(), boolean(), non_neg_integer()) :: state()
  defp close_if_self_closing(state, true, stop), do: close_top(state, stop)
  defp close_if_self_closing(state, false, _stop), do: state

  # The element's matrix: its own transform after its parent's. nil (and a :skipped entry) when
  # its transform can't be read.
  @spec own_matrix(map(), TransformList.matrix(), String.t(), state()) ::
          {TransformList.matrix() | nil, state()}
  defp own_matrix(attrs, parent, name, state) do
    case TransformList.parse(attrs["transform"]) do
      {:ok, own} ->
        {TransformList.multiply(parent, own), state}

      # Kept as markup, except the <svg> itself, which draws nothing then.
      {:error, message} ->
        {nil,
         skip(state, name, attrs, {:invalid_transform, message}, kept_unless_root(name, state))}
    end
  end

  @spec start_matrix(keyword()) :: TransformList.matrix()
  defp start_matrix(opts), do: flip_matrix(flip?(opts))

  # Any truthy :flip_y flips, like the other options.
  @spec flip?(keyword()) :: boolean()
  defp flip?(opts), do: Keyword.get(opts, :flip_y, false) not in [false, nil]

  @spec flip_matrix(boolean()) :: TransformList.matrix()
  defp flip_matrix(false), do: TransformList.identity()
  defp flip_matrix(true), do: @flip

  # A flipped drawing's view box is flipped too, so it still shows the picture.
  @spec flip_view_box(tuple() | nil, boolean()) :: tuple() | nil
  defp flip_view_box({x, y, w, h}, true), do: {x, -(y + h), w, h}
  defp flip_view_box(view_box, _flipped), do: view_box

  @spec push(
          state(),
          String.t(),
          atom(),
          TransformList.matrix() | nil,
          non_neg_integer(),
          term(),
          boolean()
        ) ::
          state()
  defp push(state, _name, _kind, _matrix, _start, _node, true = _self_closing), do: state

  defp push(state, name, kind, matrix, start, node, false) do
    frame = %{name: name, kind: kind, matrix: matrix, start: start, node: node, children: []}
    %{state | stack: [frame | state.stack], open: Map.update(state.open, name, 1, &(&1 + 1))}
  end

  # Closes `name` and anything left open inside it. A stray closing tag changes nothing. `open`
  # counts the open elements by name, so a stray one is found without searching the stack (which,
  # in a deeply nested document full of stray tags, would take time in proportion to its square).
  @spec pop(state(), String.t(), non_neg_integer(), non_neg_integer()) :: state()
  defp pop(%{open: open} = state, name, start, stop) when :erlang.map_get(name, open) > 0,
    do: pop_until(state, name, start, stop)

  defp pop(state, _name, _start, _stop), do: state

  # Closes the innermost element, and if it isn't `name`, the next one, and so on. The element
  # that matches ends at `stop` (after its closing tag); ones left open inside it end at `start`.
  @spec pop_until(state(), String.t(), non_neg_integer(), non_neg_integer()) :: state()
  defp pop_until(%{stack: [%{name: name} | _]} = state, name, _start, stop),
    do: close_top(state, stop)

  defp pop_until(state, name, start, stop),
    do: state |> close_top(start) |> pop_until(name, start, stop)

  # Closes the innermost element, which ends at `stop`, and adds what it became to its parent.
  @spec close_top(state(), non_neg_integer()) :: state()
  defp close_top(%{stack: [frame | stack], open: open} = state, stop) do
    state = %{state | stack: stack, open: Map.update!(open, frame.name, &(&1 - 1))}
    finish(frame, stop, state)
  end

  @spec finish(frame(), non_neg_integer(), state()) :: state()
  defp finish(%{kind: :root, children: children}, _stop, %{drawing: drawing} = state),
    do: %{state | drawing: %{drawing | children: Enum.reverse(children)}}

  defp finish(%{kind: :group, node: group, children: children}, _stop, state),
    do: add_child(state, %{group | children: Enum.reverse(children)})

  defp finish(%{kind: :raw, name: name, matrix: matrix, start: start}, stop, state) do
    markup = state.svg |> binary_part(start, stop - start) |> clean()
    add_child(state, %Raw{element: name, markup: markup, transform: matrix})
  end

  defp finish(%{kind: :ignore}, _stop, state), do: state

  # Adds a shape, group or raw markup to the innermost open element.
  @spec add_child(state(), Drawing.child()) :: state()
  defp add_child(%{stack: [parent | stack]} = state, child),
    do: %{state | stack: [%{parent | children: [child | parent.children]} | stack]}

  # The root <svg> is the only element with no parent open.
  @spec kept_unless_root(String.t(), state()) :: :as_markup | :no
  defp kept_unless_root("svg", %{stack: []}), do: :no
  defp kept_unless_root(_name, _state), do: :as_markup

  # Lists an element in :skipped: why it wasn't read as curves, and what was kept of it.
  @spec skip(state(), String.t(), map(), term(), :as_markup | :partly | :no) :: state()
  defp skip(%{drawing: drawing} = state, name, attrs, reason, kept) do
    entry = %{element: name, id: attrs["id"], reason: reason, kept: kept}
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

  # Adds the shape, or skips it, and says whether to keep its markup instead (:raw): when its
  # transform couldn't be read (it was already skipped) or a size has a unit Curves can't measure,
  # the SVG's viewer still draws it. Shapes SVG doesn't draw (:empty, or an error) aren't kept.
  @spec shape(Shape.element(), map(), TransformList.matrix() | nil, state()) ::
          {state(), :raw | :ignore}
  defp shape(_kind, _attrs, nil, state), do: {state, :raw}

  defp shape(kind, attrs, matrix, state) do
    state = %{state | matrix: matrix}

    case subpaths(kind, attrs, matrix) do
      {:ok, subpaths} ->
        {add(state, kind, attrs, subpaths), :ignore}

      {:partial, subpaths, reason} ->
        {state |> add(kind, attrs, subpaths) |> skip(name(kind), attrs, reason, :partly), :ignore}

      {:skip, {:unsupported_unit, _} = reason} ->
        {skip(state, name(kind), attrs, reason, :as_markup), :raw}

      {:skip, reason} ->
        {skip(state, name(kind), attrs, reason, :no), :ignore}
    end
  end

  @spec name(Shape.element()) :: String.t()
  defp name(kind), do: Atom.to_string(kind)

  # A shape with no subpaths at all (e.g. path data that fails straight away) isn't added.
  @spec add(state(), Shape.element(), map(), list(Subpath.t())) :: state()
  defp add(state, _kind, _attrs, []), do: state

  defp add(state, kind, attrs, subpaths) do
    shape = %Shape{
      element: kind,
      id: attrs["id"],
      subpaths: subpaths,
      attributes: attrs,
      transform: state.matrix
    }

    add_child(state, shape)
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
