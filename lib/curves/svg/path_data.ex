defmodule Curves.Svg.PathData do
  @moduledoc false
  # Reads SVG path data (the `d` attribute of a <path>) into bezier spline points, one list per
  # subpath, ready for Curves.define_bezier_spline/2.
  #
  # Every command is supported, absolute (upper case) and relative (lower case):
  # M L H V (lines), C S (cubic curves), Q T (quadratic curves), A (arcs) and Z (close).
  # The grammar is SVG's: separators are optional where the numbers can't run together, so
  # "M0,0L10-5.5.5" is M 0 0 L 10 -5.5 L .5 ... and arc flags can be squashed ("a1 1 0 0010 10").
  #
  # Like a browser, it reads up to the first error and returns what it has, with the error.
  alias Curves.Types, as: T

  # One subpath: bezier spline points, and whether it was closed with Z.
  @type subpath() :: {list(list()), boolean()}

  # The parser's state. `knots` holds {knot, to_next} for the subpath being read, newest first:
  # `to_next` is the control points (or arc) of the curve from that knot to the next one.
  # `previous` is the last command (as an upper case letter) and its last control point, which
  # S and T reflect.
  @typep state() :: %{
           current: T.point_tuple(),
           start: T.point_tuple(),
           knots: list({T.point_tuple(), list()}),
           closed: boolean(),
           previous: {String.t() | nil, T.point_tuple() | nil},
           done: list(subpath())
         }

  # How many numbers each command takes. An arc's 4th and 5th values are flags.
  @arity %{
    "M" => 2,
    "L" => 2,
    "H" => 1,
    "V" => 1,
    "C" => 6,
    "S" => 4,
    "Q" => 4,
    "T" => 2,
    "A" => 7,
    "Z" => 0
  }

  # The subpaths, or the subpaths read before an error and the error.
  @spec parse(String.t()) :: {:ok, list(subpath())} | {:error, list(subpath()), String.t()}
  def parse(data) when is_binary(data) do
    state = %{
      current: {0.0, 0.0},
      start: {0.0, 0.0},
      knots: [],
      closed: false,
      previous: {nil, nil},
      done: []
    }

    data |> skip_space() |> first_command(state)
  end

  # Path data must start with a moveto (or be empty).
  @spec first_command(binary(), state()) ::
          {:ok, list(subpath())} | {:error, list(subpath()), String.t()}
  defp first_command("", state), do: finish(state, nil)
  defp first_command(<<c, _::binary>> = data, state) when c in [?M, ?m], do: commands(data, state)

  defp first_command(data, state),
    do: finish(state, "path data must start with M or m, got: #{snippet(data)}")

  # Reads one command letter, then its arguments, as many times as they repeat.
  @spec commands(binary(), state()) ::
          {:ok, list(subpath())} | {:error, list(subpath()), String.t()}
  defp commands("", state), do: finish(state, nil)

  defp commands(<<letter, rest::binary>>, state) when letter in ~c"MmLlHhVvCcSsQqTtAaZz" do
    arguments(skip_space(rest), <<letter>>, state, :first)
  end

  defp commands(data, state), do: finish(state, "expected a path command, got: #{snippet(data)}")

  # Reads the arguments of one command. After the first set, more numbers repeat the command
  # (a moveto repeats as a lineto). Z takes none.
  @spec arguments(binary(), String.t(), state(), :first | :repeat) ::
          {:ok, list(subpath())} | {:error, list(subpath()), String.t()}
  defp arguments(data, letter, state, _which) when letter in ["Z", "z"],
    do: data |> skip_space() |> commands(close(state))

  # A comma may separate one set from the next (SVG allows "L1 2,3 4"); a set must follow it.
  defp arguments(<<?,, rest::binary>>, letter, state, :repeat),
    do: arguments(skip_space(rest), letter, state, :first)

  # After the first set, anything but a number is the next command.
  defp arguments(<<c, _::binary>> = data, _letter, state, :repeat)
       when c not in ~c"+-.0123456789",
       do: commands(data, state)

  defp arguments("", _letter, state, :repeat), do: commands("", state)

  defp arguments(data, letter, state, _which) do
    case read_args(data, String.upcase(letter), []) do
      {:ok, args, rest} ->
        state = run(letter, args, state)
        arguments(skip_space(rest), repeat_as(letter), state, :repeat)

      {:error, message} ->
        finish(state, "#{message} in the #{letter} command")
    end
  end

  # A moveto's extra pairs are linetos.
  @spec repeat_as(String.t()) :: String.t()
  defp repeat_as("M"), do: "L"
  defp repeat_as("m"), do: "l"
  defp repeat_as(letter), do: letter

  # Reads the numbers (and flags) of one command.
  @spec read_args(binary(), String.t(), list(float() | boolean())) ::
          {:ok, list(float() | boolean()), binary()} | {:error, String.t()}
  defp read_args(data, letter, args) when length(args) == :erlang.map_get(letter, @arity),
    do: {:ok, Enum.reverse(args), data}

  defp read_args(data, "A", args) when length(args) in [3, 4] do
    case skip_separator(data) do
      <<flag, rest::binary>> when flag in [?0, ?1] -> read_args(rest, "A", [flag == ?1 | args])
      other -> {:error, "expected an arc flag (0 or 1), got: #{snippet(other)}"}
    end
  end

  defp read_args(data, letter, args) do
    case number(data) do
      {:ok, value, rest} -> read_args(rest, letter, [value | args])
      error -> error
    end
  end

  # One SVG number at the start of `data` (after any spaces and a comma), and what follows it.
  # Shared with Curves.Svg.Import for lengths and point lists, so they read numbers the same way.
  # It is read by hand, not with a regex: Erlang's regexes take time in proportion to the whole
  # remaining text on every call, which made long paths take time in proportion to their square.
  @spec number(binary()) :: {:ok, float(), binary()} | {:error, String.t()}
  def number(data) do
    data = skip_separator(data)
    {sign, after_sign} = take_sign(data)
    {whole, after_whole} = take_digits(after_sign)
    {fraction, after_fraction} = take_fraction(after_whole)
    read_number(sign, whole, fraction, after_fraction, data)
  end

  # A number needs a digit before or after its point.
  @spec read_number(binary(), binary(), binary() | nil, binary(), binary()) ::
          {:ok, float(), binary()} | {:error, String.t()}
  defp read_number(_sign, "", fraction, _rest, data) when fraction in [nil, ""],
    do: {:error, "expected a number, got: #{snippet(data)}"}

  defp read_number(sign, whole, fraction, rest, data) do
    {exponent, rest} = take_exponent(rest)

    case Float.parse("#{digits(whole)}.#{digits(fraction || "")}e#{digits(exponent)}") do
      {value, ""} -> {:ok, signed(sign, value), rest}
      _too_big -> {:error, "number too big: #{snippet(data)}"}
    end
  end

  @spec take_sign(binary()) :: {binary(), binary()}
  defp take_sign(<<sign, rest::binary>>) when sign in [?+, ?-], do: {<<sign>>, rest}
  defp take_sign(data), do: {"", data}

  # The digits at the start of `data`, and the rest.
  @spec take_digits(binary()) :: {binary(), binary()}
  defp take_digits(data) do
    count = digit_count(data, 0)
    {binary_part(data, 0, count), binary_part(data, count, byte_size(data) - count)}
  end

  @spec digit_count(binary(), non_neg_integer()) :: non_neg_integer()
  defp digit_count(<<c, rest::binary>>, n) when c in ?0..?9, do: digit_count(rest, n + 1)
  defp digit_count(_data, n), do: n

  # The digits after a decimal point (maybe none), or nil when there is no point.
  @spec take_fraction(binary()) :: {binary() | nil, binary()}
  defp take_fraction("." <> rest), do: take_digits(rest)
  defp take_fraction(data), do: {nil, data}

  # An exponent like "e-3" (only when digits follow the e), as "-3".
  @spec take_exponent(binary()) :: {binary(), binary()}
  defp take_exponent(<<e, rest::binary>> = data) when e in [?e, ?E] do
    {sign, after_sign} = take_sign(rest)

    case take_digits(after_sign) do
      {"", _} -> {"", data}
      {exponent, after_exponent} -> {sign <> exponent, after_exponent}
    end
  end

  defp take_exponent(data), do: {"", data}

  # Every number in a list like SVG's `points` ("0,0 10,5 20 0"), and the error that stopped it,
  # if any.
  @spec numbers(binary()) :: {list(float()), String.t() | nil}
  def numbers(data), do: numbers(data, [])

  @spec numbers(binary(), list(float())) :: {list(float()), String.t() | nil}
  defp numbers(data, acc) do
    case {skip_space(data), number(data)} do
      {"", _} -> {Enum.reverse(acc), nil}
      {_, {:ok, value, rest}} -> numbers(rest, [value | acc])
      {_, {:error, message}} -> {Enum.reverse(acc), message}
    end
  end

  @spec signed(binary(), float()) :: float()
  defp signed("-", value), do: -value
  defp signed(_sign, value), do: value

  @spec digits(binary()) :: binary()
  defp digits(""), do: "0"
  defp digits("-"), do: "0"
  defp digits("+"), do: "0"
  defp digits(digits), do: digits

  # Runs one command with its arguments. Relative commands (lower case) are made absolute.
  @spec run(String.t(), list(float() | boolean()), state()) :: state()
  defp run(letter, args, state) do
    absolute = String.upcase(letter)
    relative? = letter != absolute
    draw(absolute, absolute_args(absolute, args, state.current, relative?), state)
  end

  @spec absolute_args(String.t(), list(float() | boolean()), T.point_tuple(), boolean()) ::
          list(float() | boolean())
  defp absolute_args(_letter, args, _current, false), do: args
  defp absolute_args("H", [x], {cx, _cy}, true), do: [cx + x]
  defp absolute_args("V", [y], {_cx, cy}, true), do: [cy + y]

  defp absolute_args("A", [rx, ry, rotation, large, sweep, x, y], {cx, cy}, true),
    do: [rx, ry, rotation, large, sweep, cx + x, cy + y]

  defp absolute_args(_letter, args, {cx, cy}, true) do
    args
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn [x, y] -> [cx + x, cy + y] end)
  end

  @spec draw(String.t(), list(float() | boolean()), state()) :: state()
  defp draw("M", [x, y], state) do
    state = end_subpath(state)
    %{state | current: {x, y}, start: {x, y}, knots: [{{x, y}, []}], previous: {"M", nil}}
  end

  defp draw("L", [x, y], state), do: line_to(state, {x, y}, "L")
  defp draw("H", [x], %{current: {_, y}} = state), do: line_to(state, {x, y}, "H")
  defp draw("V", [y], %{current: {x, _}} = state), do: line_to(state, {x, y}, "V")

  defp draw("C", [x1, y1, x2, y2, x, y], state),
    do: curve_to(state, [{x1, y1}, {x2, y2}], {x, y}, {"C", {x2, y2}})

  defp draw("S", [x2, y2, x, y], state),
    do: curve_to(state, [reflect(state, {"C", "S"}), {x2, y2}], {x, y}, {"S", {x2, y2}})

  defp draw("Q", [x1, y1, x, y], state),
    do: curve_to(state, [{x1, y1}], {x, y}, {"Q", {x1, y1}})

  defp draw("T", [x, y], state) do
    control = reflect(state, {"Q", "T"})
    curve_to(state, [control], {x, y}, {"T", control})
  end

  defp draw("A", [rx, ry, rotation, large, sweep, x, y], state),
    do: curve_to(state, [{:arc, rx, ry, rotation, large, sweep}], {x, y}, {"A", nil})

  # S and T start with the last command's control point mirrored through the current point, but
  # only straight after the same kind of curve; otherwise with the current point itself.
  @spec reflect(state(), {String.t(), String.t()}) :: T.point_tuple()
  defp reflect(%{previous: {letter, {px, py}}, current: {cx, cy}}, {kind1, kind2})
       when letter == kind1 or letter == kind2,
       do: {2 * cx - px, 2 * cy - py}

  defp reflect(%{current: current}, _kinds), do: current

  @spec line_to(state(), T.point_tuple(), String.t()) :: state()
  defp line_to(state, point, letter), do: curve_to(state, [], point, {letter, nil})

  # Adds a curve from the current point to `point`. After a Z, drawing starts a new subpath at the
  # start of the closed one.
  @spec curve_to(state(), list(), T.point_tuple(), {String.t(), T.point_tuple() | nil}) :: state()
  defp curve_to(%{knots: []} = state, to_next, point, previous) do
    curve_to(%{state | knots: [{state.current, []}], closed: false}, to_next, point, previous)
  end

  defp curve_to(%{knots: [{knot, _} | knots]} = state, to_next, point, previous) do
    %{state | knots: [{point, []}, {knot, to_next} | knots], current: point, previous: previous}
  end

  # Z: a straight line back to the start (unless already there), and the subpath ends. The next
  # command starts from the start.
  @spec close(state()) :: state()
  defp close(%{knots: []} = state), do: state

  defp close(%{current: current, start: start} = state) do
    state = line_back(state, current == start)
    end_subpath(%{state | closed: true, current: start, previous: {"Z", nil}})
  end

  @spec line_back(state(), boolean()) :: state()
  defp line_back(state, true = _already_there), do: state
  defp line_back(state, false), do: line_to(state, state.start, "Z")

  # Moves the subpath being read into `done`. A subpath that never drew anything (a lone M, or
  # an M straight after a Z) draws nothing, so it is dropped.
  @spec end_subpath(state()) :: state()
  defp end_subpath(%{knots: knots} = state) when length(knots) < 2,
    do: %{state | knots: [], closed: false}

  defp end_subpath(%{knots: knots, closed: closed, done: done} = state) do
    points = knots |> Enum.reverse() |> Enum.map(fn {knot, to_next} -> [knot | to_next] end)
    %{state | knots: [], closed: false, done: [{points, closed} | done]}
  end

  @spec finish(state(), String.t() | nil) ::
          {:ok, list(subpath())} | {:error, list(subpath()), String.t()}
  defp finish(state, error) do
    %{done: done} = end_subpath(state)
    finished(Enum.reverse(done), error)
  end

  @spec finished(list(subpath()), String.t() | nil) ::
          {:ok, list(subpath())} | {:error, list(subpath()), String.t()}
  defp finished(subpaths, nil), do: {:ok, subpaths}
  defp finished(subpaths, error), do: {:error, subpaths, error}

  @spec skip_space(binary()) :: binary()
  defp skip_space(<<c, rest::binary>>) when c in ~c" \t\n\r\f", do: skip_space(rest)
  defp skip_space(data), do: data

  # Whitespace with at most one comma in it.
  @spec skip_separator(binary()) :: binary()
  defp skip_separator(data) do
    case skip_space(data) do
      "," <> rest -> skip_space(rest)
      rest -> rest
    end
  end

  # The start of some path data, for error messages.
  @spec snippet(binary()) :: String.t()
  defp snippet(""), do: "the end"
  # Only the first 80 bytes are looked at: String.slice/3 on the whole rest would take time in
  # proportion to its length.
  defp snippet(data),
    do: data |> binary_part(0, min(byte_size(data), 80)) |> String.slice(0, 20) |> inspect()
end
