defmodule Curves.Svg.TransformListTest do
  use ExUnit.Case, async: true
  alias Curves.Svg.TransformList

  @spec moved(String.t() | nil, {float(), float()}) :: {float(), float()}
  defp moved(text, point) do
    {:ok, matrix} = TransformList.parse(text)
    {x, y} = TransformList.move(matrix, point)
    {Float.round(x, 9) + 0.0, Float.round(y, 9) + 0.0}
  end

  test "every SVG transform" do
    assert moved("translate(10, 20)", {1.0, 1.0}) == {11.0, 21.0}
    assert moved("translate(10)", {1.0, 1.0}) == {11.0, 1.0}
    assert moved("scale(2)", {1.0, 3.0}) == {2.0, 6.0}
    assert moved("scale(2 -1)", {1.0, 3.0}) == {2.0, -3.0}
    assert moved("rotate(90)", {1.0, 0.0}) == {0.0, 1.0}
    assert moved("rotate(90 5 5)", {1.0, 1.0}) == {9.0, 1.0}
    assert moved("skewX(45)", {1.0, 1.0}) == {2.0, 1.0}
    assert moved("skewY(45)", {1.0, 1.0}) == {1.0, 2.0}
    assert moved("matrix(1 2 3 4 5 6)", {1.0, 1.0}) == {9.0, 12.0}
  end

  test "a list applies right to left" do
    assert moved("translate(10 0) scale(2)", {1.0, 1.0}) == {12.0, 2.0}
    assert moved("scale(2)translate(10 0)", {1.0, 1.0}) == {22.0, 2.0}
    assert moved(" scale(2) , translate(.5,-.5) ", {0.0, 0.0}) == {1.0, -1.0}
  end

  test "nothing is the identity" do
    assert moved(nil, {3.0, 4.0}) == {3.0, 4.0}
    assert moved("  ", {3.0, 4.0}) == {3.0, 4.0}
  end

  test "anything else is an error" do
    for bad <- [
          "foo(1)",
          "scale()",
          "rotate(1 2)",
          "translate(1 2 3)",
          "scale(2",
          "scale(x)",
          "matrix(1 2 3)"
        ] do
      assert {:error, _} = TransformList.parse(bad)
    end
  end
end
