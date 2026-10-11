defmodule Curves.ExceptionsTest do
  use ExUnit.Case
  alias Curves.Exceptions.{OutOfBoundT, OutOfBoundU, TooFewPoints, TooManyPoints}

  test "OutOfBoundT is raised for a bezier t outside 0..1, and keeps t" do
    error = assert_raise OutOfBoundT, fn -> Curves.solve!(Curves.define_bezier(:linear), 1.5) end
    assert error.t == 1.5
  end

  test "OutOfBoundU keeps u and the curve's max_u" do
    curve = Curves.define_catmull_rom([{0, 0}, {10, 100}, {20, 0}, {30, 100}])
    error = assert_raise OutOfBoundU, fn -> Curves.solve!(curve, 99.0) end
    assert {error.u, error.max} == {99.0, Curves.max_u(curve)}
  end

  test "TooFewPoints keeps the point count and the minimum" do
    error =
      assert_raise TooFewPoints, fn -> Curves.solve!(Curves.define_bezier([{1, 1}]), 0.5) end

    assert {error.n, error.min} == {1, 2}
  end

  test "TooManyPoints keeps the point count and the maximum" do
    curve = Curves.define_bezier([{0, 0}, {1, 1}, {2, 0}, {3, 1}, {4, 0}])
    error = assert_raise TooManyPoints, fn -> Curves.solve!(curve, 0.5) end
    assert {error.n, error.max} == {5, 4}
  end
end
