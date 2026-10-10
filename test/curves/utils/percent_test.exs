defmodule Curves.Utils.PercentTest do
  use ExUnit.Case
  alias Curves.Utils.Percent

  @box %{xmin: 0.0, xmax: 10.0, ymin: 0.0, ymax: 100.0}

  describe "maybe_normalize/3" do
    test "returns the point unchanged when off or missing" do
      assert Percent.maybe_normalize(@box, {5.0, 25.0}, force_percent: false) == {5.0, 25.0}
      assert Percent.maybe_normalize(@box, {5.0, 25.0}, []) == {5.0, 25.0}
    end

    test "normalizes when true" do
      assert Percent.maybe_normalize(@box, {5.0, 25.0}, force_percent: true) == {0.5, 0.25}
    end

    test "normalizes for any truthy value" do
      assert Percent.maybe_normalize(@box, {5.0, 25.0}, force_percent: 1) == {0.5, 0.25}
    end
  end

  describe "normalize/2" do
    test "flat range returns max" do
      flat = %{@box | ymin: 7, ymax: 7}
      assert Percent.normalize(flat, {5.0, 7.0}) == {0.5, 7}
    end

    test "integer coordinates raise" do
      assert_raise FunctionClauseError, fn -> Percent.normalize(@box, {5, 25}) end
    end
  end
end
