defmodule Curves.DrawingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Curves.Drawing
  alias Curves.Drawing.{Group, Raw, Shape, Subpath}
  alias Curves.Transform
  doctest Curves.Drawing

  @svg """
  <svg viewBox="0 0 100 100">
    <rect id="ground" x="0" y="80" width="100" height="20" fill="green"/>
    <g id="car" stroke="black">
      <rect id="body" x="10" y="50" width="40" height="20"/>
      <g id="wheels">
        <circle id="front" cx="20" cy="70" r="5"/>
        <circle id="back" cx="40" cy="70" r="5"/>
      </g>
      <text id="label" x="20" y="45">Car</text>
    </g>
  </svg>
  """

  @spec assert_near({float(), float()}, {float(), float()}) :: true
  defp assert_near({ax, ay}, {bx, by}) do
    assert abs(ax - bx) < 1.0e-9 and abs(ay - by) < 1.0e-9,
           "#{inspect({ax, ay})} vs #{inspect({bx, by})}"
  end

  # Where a shape's first curve starts, as drawn.
  @spec start(Drawing.t(), String.t()) :: {float(), float()}
  defp start(drawing, id) do
    shape = drawing |> Drawing.shapes() |> Enum.find(&(&1.id == id))
    Curves.solve!(hd(shape.subpaths).curve, 0.0)
  end

  describe "transforming a whole drawing" do
    test "moves, scales and rotates every shape, and its placement is kept on the drawing" do
      drawing = Curves.from_svg(@svg)
      assert_near(start(drawing, "ground"), {0.0, 80.0})

      moved = Transform.inc_position(drawing, {5, -5})
      assert moved.origin == {5.0, -5.0}
      assert_near(start(moved, "ground"), {5.0, 75.0})
      assert_near(start(moved, "front"), {30.0, 65.0})

      scaled = Transform.set_scale(drawing, 2)
      assert_near(start(scaled, "ground"), {0.0, 160.0})
    end

    test "around: :center is the middle of the whole drawing" do
      drawing = Curves.from_svg(@svg) |> Transform.set_rotation(180, around: :center)
      # The curves span 0..100 by 50..100 (the text isn't curves), so the middle is {50, 75}.
      assert_near(start(drawing, "ground"), {100.0, 70.0})
    end

    test "setting a scale again loses nothing, even after a scale of 0" do
      drawing = Curves.from_svg(@svg)
      again = drawing |> Transform.set_scale(0) |> Transform.set_scale(1)

      assert Drawing.curves(again) |> Enum.map(&Curves.solve!(&1, 0.5)) ==
               Drawing.curves(drawing) |> Enum.map(&Curves.solve!(&1, 0.5))
    end

    test "is drawn with its transform around everything, so text moves too" do
      svg = Curves.from_svg(@svg) |> Transform.inc_x(10) |> Curves.Svg.render()
      assert svg =~ ~s|<g transform="matrix(1.0 0.0 0.0 1.0 10.0 0.0)">\n<path|
      assert svg =~ ~s(>Car</text>)
    end

    test "reverse travels every curve the other way" do
      drawing = Curves.from_svg(~s|<svg><path d="M0 0 L4 0"/><line x2="2" y2="2"/></svg>|)
      reversed = Transform.reverse(drawing)

      assert reversed |> Drawing.curves() |> Enum.map(&Curves.solve!(&1, 0.0)) == [
               {4.0, 0.0},
               {2.0, 2.0}
             ]
    end
  end

  describe "transforming part of a drawing" do
    test "a group moves everything in it, and nothing else" do
      drawing = Curves.from_svg(@svg) |> Drawing.update("wheels", &Transform.inc_y(&1, 3))
      assert_near(start(drawing, "front"), {25.0, 73.0})
      assert_near(start(drawing, "body"), {10.0, 50.0})
      assert %Group{origin: {0.0, 3.0}} = Drawing.get(drawing, "wheels")
    end

    test "a group's :center is its own middle" do
      drawing =
        Curves.from_svg(@svg) |> Drawing.update("wheels", &Transform.flip_x(&1, around: :center))

      # The wheels span x 15..45, so flipping around 30 swaps them: the front wheel's start {25, 70} goes to {35, 70}.
      assert_near(start(drawing, "front"), {35.0, 70.0})
    end

    test "a shape keeps its own transform, which goes on its path so its stroke scales" do
      drawing = Curves.from_svg(@svg) |> Drawing.update("body", &Transform.set_scale(&1, 2))
      assert_near(start(drawing, "body"), {20.0, 100.0})

      assert Curves.Svg.render(drawing) =~
               ~s|transform="matrix(2.0 0.0 0.0 2.0 0.0 0.0)" id="body"|
    end

    test "a subpath changes its curve, like a curve" do
      subpath = %Subpath{curve: Curves.define_polyline([{0, 0}, {1, 0}]), closed: false}
      assert %Subpath{curve: curve} = Transform.set_position(subpath, {3, 3})
      assert Curves.solve!(curve, 0.0) == {3.0, 3.0}
    end

    test "raw markup can't be transformed on its own" do
      assert_raise ArgumentError, ~r/expected a Curves.Bezier.Curve/, fn ->
        Transform.inc_x(%Raw{}, 1)
      end
    end
  end

  describe "finding and changing parts by id" do
    test "fetch, get and get_in look anywhere inside, and get_in follows a path" do
      drawing = Curves.from_svg(@svg)
      assert {:ok, %Shape{element: :circle}} = Drawing.fetch(drawing, "back")
      assert Drawing.get(drawing, "label") == nil
      assert %Group{id: "wheels"} = Drawing.get_in(drawing, ["car", "wheels"])
      assert Drawing.get_in(drawing, ["car", "wheels", "front"]).id == "front"
      assert Drawing.get_in(drawing, ["wheels", "car"]) == nil
      assert Drawing.get_in(drawing, ["body", "front"]) == nil
    end

    test "put, update, update_in and delete change exactly one part" do
      drawing = Curves.from_svg(@svg)
      back = Drawing.get(drawing, "back")

      drawing =
        Drawing.put(drawing, "front", %{back | id: "front", attributes: %{"fill" => "red"}})

      assert Drawing.get(drawing, "front").attributes == %{"fill" => "red"}

      drawing = Drawing.update_in(drawing, ["car", "wheels", "back"], &Transform.inc_x(&1, 1))
      assert Drawing.get(drawing, "back").origin == {1.0, 0.0}

      drawing = Drawing.delete(drawing, "wheels")
      assert drawing |> Drawing.shapes() |> Enum.map(& &1.id) == ["ground", "body"]
    end

    test "something missing, a wrong replacement, or looking inside a shape raises" do
      drawing = Curves.from_svg(@svg)

      assert_raise ArgumentError, ~s(there is no shape or group with the id "boat"), fn ->
        Drawing.update(drawing, "boat", & &1)
      end

      assert_raise ArgumentError, ~r/expected a Curves.Drawing.Shape, Group or Raw/, fn ->
        Drawing.put(drawing, "body", :wheel)
      end

      assert_raise ArgumentError,
                   ~s("body" is a shape, so there is nothing inside it to look for),
                   fn ->
                     Drawing.update_in(drawing, ["body", "front"], & &1)
                   end

      assert_raise ArgumentError, fn -> update_in(drawing, [Drawing.by_id("boat")], & &1) end
    end

    test "by_id works with Elixir's get_in, update_in and pop_in" do
      drawing = Curves.from_svg(@svg)
      path = [Drawing.by_id("car"), Drawing.by_id("front")]
      assert get_in(drawing, path).id == "front"
      assert get_in(drawing, [Drawing.by_id("boat")]) == nil

      moved = update_in(drawing, path, &Transform.inc_x(&1, 2))
      assert_near(start(moved, "front"), {27.0, 70.0})

      {%Shape{id: "front"}, popped} = pop_in(drawing, path)
      assert Drawing.get(popped, "front") == nil
    end

    test "update_shapes and update_curves change every part, in groups too" do
      drawing =
        Curves.from_svg(@svg) |> Drawing.update_shapes(&put_in(&1.attributes["stroke"], "red"))

      assert drawing |> Drawing.shapes() |> Enum.all?(&(&1.attributes["stroke"] == "red"))

      drawing = Drawing.update_curves(drawing, &Transform.inc_x(&1, 1))
      assert_near(start(drawing, "ground"), {1.0, 80.0})
      assert_near(start(drawing, "back"), {46.0, 70.0})
    end
  end

  test "every skip says what was kept" do
    drawing =
      Curves.from_svg(
        ~s|<svg><text>A</text><script>x</script><rect width="5%" height="1"/><g transform="spin(1)"/>| <>
          ~s|<path d="M0 0 L1 1 L2"/><polyline points="0 0 1 1 2"/><circle r="-1"/><circle r="0"/></svg>|
      )

    assert Enum.map(drawing.skipped, &{&1.element, &1.reason, &1.kept}) ==
             [
               {"text", :not_curves, :as_markup},
               {"script", :unsafe, :no},
               {"rect", {:unsupported_unit, "5%"}, :as_markup},
               {"g", {:invalid_transform, "can't read the transform \"spin(1)\""}, :as_markup},
               {"path", {:invalid_path, "expected a number, got: the end in the L command"},
                :partly},
               {"polyline", {:invalid, "points: an odd number of coordinates"}, :partly},
               {"circle", {:invalid, "r can't be negative, got: -1.0"}, :no},
               {"circle", :empty, :no}
             ]

    root = Curves.from_svg(~s|<svg transform="oops"><circle r="1"/></svg>|)
    assert [%{element: "svg", kept: :no}] = root.skipped
  end

  # A random drawing: a couple of groups and shapes.
  @shapes [
    ~s|<path d="M0 0 L10 0 A5 3 30 0 1 10 10 Q5 15 0 10 z"/>|,
    ~s|<circle cx="2" cy="1" r="4"/>|,
    ~s|<rect id="r" x="1" y="1" width="6" height="4" rx="1.5"/>|,
    ~s|<polygon points="0,0 4,1 2,5"/>|
  ]

  # A random change to a drawing, a group or a shape.
  @spec change() :: StreamData.t((term() -> term()))
  defp change do
    StreamData.member_of([
      &Transform.inc_position(&1, {3, -2}),
      &Transform.set_scale(&1, {2, 0.5}),
      &Transform.inc_rotation(&1, 30, around: :center),
      &Transform.flip_y(&1, around: :center),
      &Transform.set_scale(&1, -1.5, around: {1, 1}),
      & &1
    ])
  end

  @spec furthest(Curves.Types.curve_struct(), Curves.Types.curve_struct()) :: float()
  defp furthest(a, b) do
    dense = [Curves.solve!(b, 0.0) | Curves.take!(b, 1500)]

    for i <- 0..40, reduce: 0.0 do
      acc ->
        {x, y} = Curves.solve!(a, i / 40 * Curves.max_u(a))

        max(
          acc,
          dense
          |> Enum.map(fn {bx, by} -> :math.sqrt((bx - x) ** 2 + (by - y) ** 2) end)
          |> Enum.min()
        )
    end
  end

  property "a transformed drawing is drawn where Drawing.curves/1 says its curves are" do
    check all(
            picked <-
              StreamData.list_of(StreamData.member_of(@shapes), min_length: 1, max_length: 3),
            on_drawing <- change(),
            on_group <- change(),
            on_shapes <- change()
          ) do
      drawing =
        Curves.from_svg(
          ~s|<svg><g id="g" transform="rotate(10)">#{Enum.join(picked)}</g><text>T</text></svg>|
        )
        |> on_drawing.()
        |> Drawing.update("g", on_group)
        |> Drawing.update_shapes(on_shapes)

      again = drawing |> Curves.Svg.render() |> Curves.from_svg()

      for {a, b} <- Enum.zip(Drawing.curves(drawing), Drawing.curves(again)) do
        # 1500 samples are this far apart at most, relative to the curve's size.
        %{xmin: xmin, xmax: xmax, ymin: ymin, ymax: ymax} =
          Curves.Utils.Vec.bounds(Curves.take!(a, 100))

        assert furthest(a, b) <= 0.01 * max(1.0, max(xmax - xmin, ymax - ymin))
      end

      assert length(Drawing.curves(again)) == length(Drawing.curves(drawing))
    end
  end
end
