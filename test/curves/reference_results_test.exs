defmodule Curves.ReferenceResultsTest do
  # Checks every curve in Curves.Support.ReferenceResults still gives the recorded results.
  use ExUnit.Case, async: true
  alias Curves.Support.ReferenceResults

  # Read at run time, so a regenerated fixture is always picked up.
  setup_all do
    %{recorded: ReferenceResults.read!(), builders: Map.new(ReferenceResults.cases())}
  end

  test "the fixture covers every case", %{recorded: recorded} do
    names = ReferenceResults.cases() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    assert names == recorded |> Map.keys() |> Enum.sort()
  end

  # Anonymous functions can't be stored in module attributes, so each test looks its builder up by name.
  for {name, _build} <- ReferenceResults.cases() do
    @name name

    test "#{name} matches the reference results", %{recorded: recorded, builders: builders} do
      expected = Map.fetch!(recorded, @name)
      # Recorded with 64-bit floats. Once :float_dtype is removed, this option is simply ignored.
      actual = ReferenceResults.record(Map.fetch!(builders, @name).(float_dtype: 64))
      tolerance = ReferenceResults.tolerance(@name)

      for key <- [:solve, :solve_percent, :take, :take_percent] do
        assert_close(actual[key], expected[key], tolerance, "#{@name} #{key}")
      end

      assert_same_svg(actual.svg, expected.svg, @name)
    end
  end

  # Compares nested results (tuples, lists, {:ok, _} / {:error, _}) with floats within `tolerance`,
  # relative to the size of the value (and absolute near zero).
  @spec assert_close(term(), term(), float(), String.t()) :: true
  defp assert_close(a, b, tolerance, where) when is_float(a) and is_float(b) do
    scale = max(1.0, max(abs(a), abs(b)))
    assert abs(a - b) <= tolerance * scale, "#{where}: #{a} vs #{b}"
  end

  defp assert_close(a, b, tolerance, where) when is_tuple(a) and is_tuple(b),
    do: assert_close(Tuple.to_list(a), Tuple.to_list(b), tolerance, where)

  defp assert_close(a, b, tolerance, where) when is_list(a) and is_list(b) do
    assert length(a) == length(b), "#{where}: lengths differ"
    Enum.zip_with(a, b, &assert_close(&1, &2, tolerance, where))
    true
  end

  defp assert_close(a, b, _tolerance, where),
    do: assert(a == b, "#{where}: #{inspect(a)} vs #{inspect(b)}")

  # SVG numbers are rounded to 2 decimals, so allow a rounding flip of 0.01 in any number.
  @spec assert_same_svg(String.t(), String.t(), String.t()) :: true
  defp assert_same_svg(same, same, _name), do: true

  defp assert_same_svg(actual, expected, name) do
    number = ~r/-?\d+\.\d+/

    assert String.replace(actual, number, "N") == String.replace(expected, number, "N"),
           "#{name}: svg layout differs"

    pairs = Enum.zip(Regex.scan(number, actual), Regex.scan(number, expected))

    for {[a], [b]} <- pairs do
      assert abs(String.to_float(a) - String.to_float(b)) <= 0.0101, "#{name}: svg #{a} vs #{b}"
    end

    true
  end
end
