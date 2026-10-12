defmodule Curves.Svg.TransformList do
  @moduledoc false
  # Reads an SVG `transform` attribute, e.g. "translate(10, 20) rotate(30) scale(2)", into one
  # matrix. Every SVG transform works: matrix, translate, scale, rotate (with or without a centre),
  # skewX and skewY.
  #
  # A matrix {a, b, c, d, e, f} moves the point {x, y} to {a*x + c*y + e, b*x + d*y + f}, like SVG's
  # matrix(a, b, c, d, e, f). A list applies right to left, so "translate(10) scale(2)" scales first.
  alias Curves.Types, as: T

  @type matrix() :: {float(), float(), float(), float(), float(), float()}

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  # One transform, its name and numbers, e.g. "rotate(30, 5, 5)".
  @one ~r/\A\s*,?\s*(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)/

  @spec identity() :: matrix()
  def identity(), do: @identity

  # The matrix for a transform attribute (nil or "" is no transform).
  @spec parse(String.t() | nil) :: {:ok, matrix()} | {:error, String.t()}
  def parse(nil), do: {:ok, @identity}
  def parse(text), do: text |> String.trim() |> parse_list(@identity)

  @spec parse_list(binary(), matrix()) :: {:ok, matrix()} | {:error, String.t()}
  defp parse_list("", matrix), do: {:ok, matrix}

  defp parse_list(text, matrix) do
    with [whole, name, args] <- Regex.run(@one, text),
         {:ok, numbers} <- numbers(args),
         {:ok, next} <- transform(name, numbers) do
      text
      |> binary_part(byte_size(whole), byte_size(text) - byte_size(whole))
      |> String.trim()
      |> parse_list(multiply(matrix, next))
    else
      _ -> {:error, "can't read the transform #{inspect(text)}"}
    end
  end

  @spec numbers(String.t()) :: {:ok, list(float())} | :error
  defp numbers(args) do
    case Curves.Svg.PathData.numbers(args) do
      {numbers, nil} -> {:ok, numbers}
      {_numbers, _error} -> :error
    end
  end

  # One transform's matrix. Angles are in degrees.
  @spec transform(String.t(), list(float())) :: {:ok, matrix()} | :error
  defp transform("matrix", [a, b, c, d, e, f]), do: {:ok, {a, b, c, d, e, f}}
  defp transform("translate", [x]), do: {:ok, {1.0, 0.0, 0.0, 1.0, x, 0.0}}
  defp transform("translate", [x, y]), do: {:ok, {1.0, 0.0, 0.0, 1.0, x, y}}
  defp transform("scale", [s]), do: {:ok, {s, 0.0, 0.0, s, 0.0, 0.0}}
  defp transform("scale", [sx, sy]), do: {:ok, {sx, 0.0, 0.0, sy, 0.0, 0.0}}

  defp transform("rotate", [angle]) do
    {cos, sin} = cos_sin(angle)
    {:ok, {cos, sin, -sin, cos, 0.0, 0.0}}
  end

  # Around {cx, cy}: move it to {0, 0}, rotate, and move it back.
  defp transform("rotate", [angle, cx, cy]) do
    {:ok, rotation} = transform("rotate", [angle])

    {:ok,
     multiply({1.0, 0.0, 0.0, 1.0, cx, cy}, multiply(rotation, {1.0, 0.0, 0.0, 1.0, -cx, -cy}))}
  end

  defp transform("skewX", [angle]), do: {:ok, {1.0, 0.0, tan(angle), 1.0, 0.0, 0.0}}
  defp transform("skewY", [angle]), do: {:ok, {1.0, tan(angle), 0.0, 1.0, 0.0, 0.0}}
  defp transform(_name, _numbers), do: :error

  @spec cos_sin(float()) :: {float(), float()}
  defp cos_sin(degrees) do
    radians = degrees * :math.pi() / 180
    {:math.cos(radians), :math.sin(radians)}
  end

  @spec tan(float()) :: float()
  defp tan(degrees), do: :math.tan(degrees * :math.pi() / 180)

  # The matrix that applies `second` first, then `first`.
  @spec multiply(matrix(), matrix()) :: matrix()
  def multiply({a1, b1, c1, d1, e1, f1}, {a2, b2, c2, d2, e2, f2}) do
    {a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2, b1 * c2 + d1 * d2,
     a1 * e2 + c1 * f2 + e1, b1 * e2 + d1 * f2 + f1}
  end

  # Moves a point by the matrix.
  @spec move(matrix(), T.point_tuple()) :: T.point_tuple()
  def move({a, b, c, d, e, f}, {x, y}), do: {a * x + c * y + e, b * x + d * y + f}
end
