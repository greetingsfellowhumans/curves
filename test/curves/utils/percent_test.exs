defmodule Curves.Utils.PercentTest do
  use ExUnit.Case
  alias Curves.Utils.Percent

  @box %{xmin: 0.0, xmax: 10.0, ymin: 0.0, ymax: 100.0}

  describe "get_bounds/1" do
    test "finds the lowest and highest x and y" do
      points = [{0.0, 5.0}, {10.0, 1.0}, {4.0, 3.0}]
      assert Percent.get_bounds(points) == %{xmin: 0.0, xmax: 10.0, ymin: 1.0, ymax: 5.0}
    end

    test "matches the bounds stored by define" do
      curve = Curves.define_bezier([{10, 100}, {40, 400}, {25, -3}])
      assert Percent.get_bounds(curve.points) == Map.take(curve, [:xmin, :xmax, :ymin, :ymax])
    end

    test "flat axis gives equal min and max" do
      points = [{0.0, 7.0}, {1.0, 7.0}]
      assert %{ymin: 7.0, ymax: 7.0} = Percent.get_bounds(points)
    end
  end

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
    test "flat range returns 0.5" do
      flat = %{@box | ymin: 7, ymax: 7}
      assert Percent.normalize(flat, {5.0, 7.0}) == {0.5, 0.5}
    end

    test "integer coordinates raise" do
      # apply/3 keeps the compiler's type checker from warning about the deliberately wrong input.
      assert_raise FunctionClauseError, fn -> apply(Percent, :normalize, [@box, {5, 25}]) end
    end
  end
end
