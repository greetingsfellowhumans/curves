defmodule Curves.Svg.ImportPropertiesTest do
  # Properties of reading SVGs, checked on random input.
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Drawing

  @fragments [
    "<svg>",
    "</svg>",
    "<svg:svg>",
    "<g transform=\"",
    "scale(2)",
    "rotate(30 1 1)",
    "skewX(10)",
    "\">",
    "</g>",
    "<path d=\"",
    "M0 0",
    "L",
    "1",
    "-2.5",
    ".5e1",
    " ",
    ",",
    "A3 3 0 1 0",
    "Q",
    "T",
    "S",
    "z",
    "<circle r=\"5\"",
    "<rect width=\"4\" height=\"2\" rx=\"1\"",
    "<polygon points=\"",
    "<line x2=\"3\"",
    "<!--",
    "-->",
    "<![CDATA[",
    "]]>",
    "<?xml",
    "?>",
    "<!DOCTYPE [",
    "]>",
    "'",
    "\"",
    "<",
    ">",
    "/>",
    "&amp;",
    "&#9999999;",
    "&#x41;",
    "<defs>",
    "</defs>",
    "<text>",
    "</text>",
    "%",
    "px",
    "1e999"
  ]

  # Text that looks a bit like SVG, often broken.
  @spec svg_soup() :: StreamData.t(String.t())
  defp svg_soup do
    StreamData.map(
      StreamData.list_of(StreamData.member_of(@fragments), max_length: 40),
      &Enum.join/1
    )
  end

  property "any text gives a drawing, or an ArgumentError, and never crashes" do
    check all(
            text <-
              StreamData.one_of([svg_soup(), StreamData.binary(), StreamData.string(:printable)])
          ) do
      try do
        assert %Drawing{} = drawing = Curves.from_svg(text)
        # Every curve can be solved
        for curve <- Drawing.curves(drawing), do: Curves.solve!(curve, Curves.max_u(curve) / 2)
      rescue
        error in ArgumentError -> assert error.message =~ ~r/no <svg> element/
      end
    end
  end

  # Pieces of path data, valid and not.
  @path_pieces ~w(M m L l H h V v C c S s Q q T t A a Z z 0 1 -3 .5 e2) ++ [" ", ","]

  property "any path data gives subpaths, or an ArgumentError" do
    check all(
            data <-
              StreamData.map(
                StreamData.list_of(StreamData.member_of(@path_pieces), max_length: 30),
                &Enum.join/1
              )
          ) do
      try do
        for subpath <- Curves.from_svg_path(data), do: Curves.solve!(subpath.curve, 0.5)
      rescue
        error in ArgumentError -> assert error.message =~ ~r/invalid path data/
      end
    end
  end

  # One drawing command (no M or Z), its arguments, and whether it is written relative.
  @spec command() :: StreamData.t({String.t(), list(), boolean()})
  defp command do
    n = StreamData.float(min: -50.0, max: 50.0)
    flag = StreamData.member_of([0, 1])
    r = StreamData.float(min: 0.5, max: 30.0)

    StreamData.bind(StreamData.member_of(~w(L H V C S Q T A)), fn letter ->
      args =
        case letter do
          "L" -> StreamData.fixed_list([n, n])
          "H" -> StreamData.fixed_list([n])
          "V" -> StreamData.fixed_list([n])
          "C" -> StreamData.fixed_list([n, n, n, n, n, n])
          "S" -> StreamData.fixed_list([n, n, n, n])
          "Q" -> StreamData.fixed_list([n, n, n, n])
          "T" -> StreamData.fixed_list([n, n])
          "A" -> StreamData.fixed_list([r, r, n, flag, flag, n, n])
        end

      StreamData.tuple({StreamData.constant(letter), args, StreamData.boolean()})
    end)
  end

  # Where a command ends, from the current point (the model the parser should match).
  @spec end_point({String.t(), list(), boolean()}, {float(), float()}) :: {float(), float()}
  defp end_point({"H", [x], relative}, {cx, cy}), do: {if(relative, do: cx + x, else: x), cy}
  defp end_point({"V", [y], relative}, {cx, cy}), do: {cx, if(relative, do: cy + y, else: y)}

  defp end_point({_letter, args, relative}, {cx, cy}) do
    [x, y] = Enum.take(args, -2)
    if relative, do: {cx + x, cy + y}, else: {x, y}
  end

  property "random path data, written any valid way, goes through the knots it should" do
    check all(
            start <-
              StreamData.tuple(
                {StreamData.float(min: -50.0, max: 50.0), StreamData.float(min: -50.0, max: 50.0)}
              ),
            commands <- StreamData.list_of(command(), min_length: 1, max_length: 8),
            separator <- StreamData.member_of([" ", ",", " , ", "\n", "  "])
          ) do
      {sx, sy} = start

      data =
        Enum.map_join(commands, " ", fn {letter, args, relative} ->
          letter = if relative, do: String.downcase(letter), else: letter
          letter <> Enum.map_join(args, separator, &to_string/1)
        end)

      [subpath] = Curves.from_svg_path("M#{sx}#{separator}#{sy} " <> data)

      {knots, _} =
        Enum.map_reduce(commands, start, fn command, current ->
          {end_point(command, current), end_point(command, current)}
        end)

      [start | knots]
      |> Enum.with_index()
      |> Enum.each(fn {{x, y}, i} ->
        {ax, ay} = Curves.solve!(subpath.curve, i * 1.0)
        assert abs(ax - x) <= 1.0e-6 and abs(ay - y) <= 1.0e-6
      end)
    end
  end

  property "a transform moves every point of a shape exactly, even a skew" do
    check all(
            matrix <- StreamData.list_of(StreamData.float(min: -3.0, max: 3.0), length: 6),
            shape <-
              StreamData.member_of([
                ~s|<path d="M0 0 L10 0 A5 3 30 0 1 10 10 Q5 15 0 10 z"/>|,
                ~s|<circle cx="2" cy="1" r="4"/>|,
                ~s|<ellipse rx="5" ry="2"/>|,
                ~s|<rect x="1" y="1" width="6" height="4" rx="1.5"/>|,
                ~s|<polygon points="0,0 4,1 2,5"/>|
              ]),
            f <- StreamData.float(min: 0.0, max: 1.0)
          ) do
      [a, b, c, d, e, g] = matrix
      plain = Curves.from_svg("<svg>" <> shape <> "</svg>") |> Drawing.curves() |> hd()

      moved =
        Curves.from_svg(
          ~s|<svg><g transform="matrix(#{Enum.join(matrix, " ")})">| <> shape <> "</g></svg>"
        )
        |> Drawing.curves()
        |> hd()

      u = f * Curves.max_u(plain)
      {x, y} = Curves.solve!(plain, u)
      {mx, my} = Curves.solve!(moved, u)
      assert abs(mx - (a * x + c * y + e)) <= 1.0e-9 * 100
      assert abs(my - (b * x + d * y + g)) <= 1.0e-9 * 100
    end
  end
end
