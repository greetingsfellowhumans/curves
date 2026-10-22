defmodule Curves.Drawing do
  @moduledoc ~s"""
  A picture read from an SVG with `Curves.from_svg/2`: its shapes as curves, in the same groups and
  order, with everything else kept as markup, so `Curves.Svg` can draw it again as it was.

  ```elixir
  drawing = Curves.from_svg(File.read!("logo.svg"))

  # Every shape, wherever it is in the picture
  for shape <- Curves.Drawing.shapes(drawing), subpath <- shape.subpaths do
    Curves.solve!(subpath.curve, 0.5)
  end

  # Draw it again, as designed
  Curves.Svg.save!(drawing, "logo_again.svg")
  ```

  ## Changing it

  The `Curves.Transform` functions move, scale and rotate a whole drawing, or a group or shape in
  it, just like a curve. To change one part, find it by its `id`: `update/3` changes it with a
  function, `get/2` and `put/3` take it out and put it back, and `update_in/3` and `get_in/2` follow
  a path of ids, one inside the next. `by_id/1` does the same for Elixir's own `Kernel.get_in/2`,
  `Kernel.update_in/3` and `Kernel.pop_in/2`. `update_shapes/2` and `update_curves/2` change every
  shape or every curve.

  ```elixir
  drawing
  |> Curves.Transform.inc_position({10, 0})
  |> Curves.Drawing.update_in(["car", "front_wheel"], &Curves.Transform.inc_rotation(&1, 90, around: :center))
  |> Curves.Drawing.update_shapes(&put_in(&1.attributes["stroke"], "red"))
  ```

  | Field | What it holds |
  | --- | --- |
  | `:width`, `:height` | the `<svg>` element's `width` and `height`, as written (they may have units), or `nil` |
  | `:view_box` | its `viewBox` as `{min_x, min_y, width, height}`, or `nil` |
  | `:attributes` | all of the `<svg>` element's own attributes, as strings |
  | `:children` | what is in it, in order: a `Curves.Drawing.Shape` for each shape, a `Curves.Drawing.Group` for each group, and a `Curves.Drawing.Raw` for everything else that is kept as markup, like text |
  | `:skipped` | everything that couldn't be read as curves, and why, so nothing goes missing silently |
  | `:origin`, `:scale`, `:rotation` | how `Curves.Transform` has moved, scaled and rotated the whole drawing. They start at `{0.0, 0.0}`, `1.0` and `0.0`. |

  Each entry in `:skipped` is a map saying what the element was, why it wasn't read as curves
  (`:reason`), and what was kept of it (`:kept`):

  ```elixir
  %{element: "text",   id: "title", reason: :not_curves, kept: :as_markup}
  %{element: "script", id: nil,     reason: :unsafe,     kept: :no}
  ```

  | `:kept` | Meaning |
  | --- | --- |
  | `:as_markup` | kept as a `Curves.Drawing.Raw`, so it is drawn again just as it was, but has no curves |
  | `:partly` | some of it is kept as curves (path data with an error: the subpaths before the error) |
  | `:no` | nothing is kept: it won't be drawn again (though for `:empty` and `:invalid`, SVG doesn't draw it either) |

  So everything that won't appear when the drawing is drawn again is
  `Enum.filter(drawing.skipped, &(&1.kept == :no))`.

  | `:reason` | Meaning | `:kept` |
  | --- | --- | --- |
  | `:not_curves` | an element that isn't made of curves (`<text>`, `<image>`, `<use>`), or a nested `<svg>`, which Curves can't follow | `:as_markup` |
  | `:unsafe` | `<script>` or `<foreignObject>`, which are never kept, so a drawing drawn again can't run anything | `:no` |
  | `{:unsupported_unit, value}` | a size in `%`, `em`, `mm` and so on, which needs a screen to measure; only plain numbers and `px` are read | `:as_markup` |
  | `{:invalid_transform, message}` | a `transform` that couldn't be read; the element (for a group, everything in it) isn't read as curves | `:as_markup` (`:no` for the `<svg>` itself) |
  | `{:invalid_path, message}` | path data with an error in it; like a browser, the shape still has the subpaths before the error | `:partly` |
  | `{:invalid, message}` | a shape SVG treats as an error, like a negative radius, or (`:partly`) a polyline with an odd number of coordinates | `:no` or `:partly` |
  | `:empty` | a shape SVG doesn't draw, like a circle with radius `0` | `:no` |
  """
  # This module has its own get_in/2 and update_in/3, for paths of ids.
  import Kernel, except: [get_in: 2, update_in: 3]

  alias Curves.Drawing.{Group, Node, Raw, Shape}
  alias Curves.Utils.Matrix

  defstruct width: nil,
            height: nil,
            view_box: nil,
            attributes: %{},
            children: [],
            skipped: [],
            origin: {0.0, 0.0},
            scale: 1.0,
            rotation: 0.0

  @typedoc "A transform, `{a, b, c, d, e, f}`, like SVG's `matrix(a, b, c, d, e, f)`."
  @type matrix() :: {float(), float(), float(), float(), float(), float()}

  @typedoc "Something inside a drawing or a group."
  @type child() :: Shape.t() | Group.t() | Raw.t()

  @typedoc "Something that couldn't be read as curves. See the tables above."
  @type skipped() :: %{
          element: String.t(),
          id: String.t() | nil,
          reason: term(),
          kept: :as_markup | :partly | :no
        }

  @type t() :: %__MODULE__{
          width: String.t() | nil,
          height: String.t() | nil,
          view_box: {float(), float(), float(), float()} | nil,
          attributes: %{String.t() => String.t()},
          children: list(child()),
          skipped: list(skipped()),
          origin: Curves.Types.point_tuple(),
          scale: number() | {number(), number()},
          rotation: float()
        }

  @typedoc "A drawing, or a group in one: something with `:children`."
  @type container() :: t() | Group.t()

  @typedoc "Something that can be found by its `id`."
  @type node_with_id() :: Shape.t() | Group.t()

  @doc ~s"""
  Every shape in the drawing (or group), in order, including those inside groups, where it is
  drawn: any moves, scaling and rotation of the drawing, its groups and the shape itself (see
  `Curves.Transform`) are applied to its curves, and included in its `:transform`.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle r="1"/><g><rect width="2" height="1"/></g></svg>))
      iex> drawing |> Curves.Drawing.shapes() |> Enum.map(& &1.element)
      [:circle, :rect]
      iex> moved = Curves.Transform.inc_x(drawing, 10)
      iex> [circle | _] = Curves.Drawing.shapes(moved)
      iex> Curves.solve!(hd(circle.subpaths).curve, 0.0)
      {11.0, 0.0}
  """
  @spec shapes(container()) :: list(Shape.t())
  def shapes(%{children: children} = container),
    do: placed_shapes(children, Node.matrix(container))

  @spec placed_shapes(list(child()), Matrix.t()) :: list(Shape.t())
  defp placed_shapes(children, matrix), do: Enum.flat_map(children, &placed(&1, matrix))

  @spec placed(child(), Matrix.t()) :: list(Shape.t())
  defp placed(%Shape{} = shape, matrix),
    do: [place(shape, Matrix.multiply(matrix, Node.matrix(shape)))]

  defp placed(%Group{children: children} = group, matrix),
    do: placed_shapes(children, Matrix.multiply(matrix, Node.matrix(group)))

  defp placed(%Raw{}, _matrix), do: []

  # The shape with `matrix` applied to its curves and its transform, and its own move, scale and
  # rotation (now included) reset.
  @spec place(Shape.t(), Matrix.t()) :: Shape.t()
  defp place(shape, matrix), do: place(shape, matrix, Matrix.identity?(matrix))

  # The curves don't need moving when nothing has moved them, so reading a drawing's shapes stays
  # quick. The shape's own move, scale and rotation are still reset: they may only cancel out with
  # its groups', and are included either way.
  @spec place(Shape.t(), Matrix.t(), boolean()) :: Shape.t()
  defp place(shape, _matrix, true = _identity),
    do: %{shape | origin: {0.0, 0.0}, scale: 1.0, rotation: 0.0}

  defp place(shape, matrix, false) do
    %{
      shape
      | subpaths: Enum.map(shape.subpaths, &%{&1 | curve: Node.move_curve(&1.curve, matrix)}),
        transform: Matrix.multiply(matrix, shape.transform),
        origin: {0.0, 0.0},
        scale: 1.0,
        rotation: 0.0
    }
  end

  @doc ~s"""
  Every curve in the drawing (or group), shape by shape and subpath by subpath, in order, where it
  is drawn (see `shapes/1`).

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle r="1"/><path d="M0 0 L1 1 M5 5 L6 6"/></svg>))
      iex> drawing |> Curves.Drawing.curves() |> length()
      3
  """
  @spec curves(container()) :: list(Curves.Spline.Curve.t() | Curves.Polyline.Curve.t())
  def curves(%{children: _} = container),
    do: for(shape <- shapes(container), subpath <- shape.subpaths, do: subpath.curve)

  ## Finding and changing parts by id

  @doc ~s"""
  The shape or group with this `id`, anywhere in the drawing (or group), as `{:ok, node}`, or
  `:error` if there is none. The first one wins if several share an id.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><g id="house"><rect id="door" width="1" height="2"/></g></svg>))
      iex> {:ok, door} = Curves.Drawing.fetch(drawing, "door")
      iex> door.element
      :rect
      iex> Curves.Drawing.fetch(drawing, "garden")
      :error
  """
  @spec fetch(container(), String.t()) :: {:ok, node_with_id()} | :error
  def fetch(%{children: children}, id) when is_binary(id), do: find(children, id)

  @spec find(list(child()), String.t()) :: {:ok, node_with_id()} | :error
  defp find([], _id), do: :error
  defp find([%{id: id} = node | _], id), do: {:ok, node}

  defp find([%Group{children: children} | rest], id) do
    case find(children, id) do
      {:ok, node} -> {:ok, node}
      :error -> find(rest, id)
    end
  end

  defp find([_ | rest], id), do: find(rest, id)

  @doc ~s"""
  The shape or group with this `id`, or `nil`. See `fetch/2`.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle id="sun" r="3"/></svg>))
      iex> Curves.Drawing.get(drawing, "sun").element
      :circle
      iex> Curves.Drawing.get(drawing, "moon")
      nil
  """
  @spec get(container(), String.t()) :: node_with_id() | nil
  def get(container, id) do
    case fetch(container, id) do
      {:ok, node} -> node
      :error -> nil
    end
  end

  @doc ~s"""
  Changes the shape or group with this `id` (the first one, anywhere in the drawing) to what `fun`
  returns for it. Raises an `ArgumentError` if there is none, or if `fun` doesn't return a shape,
  group or raw markup.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><g id="wheel"><circle r="1"/></g></svg>))
      iex> drawing = Curves.Drawing.update(drawing, "wheel", &Curves.Transform.set_scale(&1, 3))
      iex> Curves.Drawing.get(drawing, "wheel").scale
      3
  """
  @spec update(container(), String.t(), (node_with_id() -> child())) :: container()
  def update(%{children: children} = container, id, fun) when is_binary(id) do
    case replace(children, id, fun) do
      {:ok, children} -> %{container | children: children}
      :error -> raise ArgumentError, "there is no shape or group with the id #{inspect(id)}"
    end
  end

  # The children with the first node of that id changed by `fun`, or :error if there is none.
  @spec replace(list(child()), String.t(), (node_with_id() -> child() | :delete)) ::
          {:ok, list(child())} | :error
  defp replace([], _id, _fun), do: :error

  defp replace([%{id: id} = node | rest], id, fun), do: {:ok, changed(fun.(node)) ++ rest}

  defp replace([%Group{children: children} = group | rest], id, fun) do
    case replace(children, id, fun) do
      {:ok, children} -> {:ok, [%{group | children: children} | rest]}
      :error -> rest |> replace(id, fun) |> prepend(group)
    end
  end

  defp replace([child | rest], id, fun), do: rest |> replace(id, fun) |> prepend(child)

  @spec prepend({:ok, list(child())} | :error, child()) :: {:ok, list(child())} | :error
  defp prepend({:ok, rest}, child), do: {:ok, [child | rest]}
  defp prepend(:error, _child), do: :error

  # What a node becomes: itself, or nothing when deleted.
  @spec changed(term()) :: list(child())
  defp changed(:delete), do: []
  defp changed(%Shape{} = node), do: [node]
  defp changed(%Group{} = node), do: [node]
  defp changed(%Raw{} = node), do: [node]

  defp changed(other) do
    raise ArgumentError,
          "expected a Curves.Drawing.Shape, Group or Raw to put in the drawing, got: #{inspect(other)}"
  end

  # What update_shapes/2's function returned, which can't be :delete.
  @spec one_node(term()) :: child()
  defp one_node(:delete) do
    raise ArgumentError,
          "update_shapes/2 can't take shapes out: its function must return a shape, group or raw markup (use delete/2 instead)"
  end

  defp one_node(node), do: node |> changed() |> hd()

  @doc ~s"""
  Puts `node` (a shape, group or raw markup) in place of the shape or group with this `id`. Raises
  an `ArgumentError` if there is none. Handy to take a part out, change it, and put it back.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle id="sun" r="3"/></svg>))
      iex> sun = Curves.Drawing.get(drawing, "sun")
      iex> drawing = Curves.Drawing.put(drawing, "sun", Curves.Transform.flip_x(sun))
      iex> Curves.Drawing.get(drawing, "sun").scale
      {-1.0, 1.0}
  """
  @spec put(container(), String.t(), child()) :: container()
  def put(container, id, node), do: update(container, id, fn _ -> node end)

  @doc ~s"""
  Takes the shape or group with this `id` out of the drawing. Raises an `ArgumentError` if there
  is none.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle id="sun" r="3"/><rect width="1" height="1"/></svg>))
      iex> drawing |> Curves.Drawing.delete("sun") |> Curves.Drawing.shapes() |> Enum.map(& &1.element)
      [:rect]
  """
  @spec delete(container(), String.t()) :: container()
  def delete(container, id), do: update(container, id, fn _ -> :delete end)

  @doc ~s"""
  Like `get/2`, following a path of ids: each id is looked for inside the one before it. Returns
  `nil` if any of them isn't there.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><g id="car"><circle id="wheel" r="1"/></g><circle id="wheel" r="9"/></svg>))
      iex> Curves.Drawing.get_in(drawing, ["car", "wheel"]).attributes["r"]
      "1"
  """
  @spec get_in(container(), list(String.t())) :: child() | nil
  def get_in(node, []), do: node

  def get_in(%{children: _} = container, [id | path]),
    do: container |> get(id) |> get_in_rest(path)

  def get_in(_node, _path), do: nil

  @spec get_in_rest(child() | nil, list(String.t())) :: child() | nil
  defp get_in_rest(nil, _path), do: nil
  defp get_in_rest(node, path), do: get_in(node, path)

  @doc ~s"""
  Like `update/3`, following a path of ids: each id is looked for inside the one before it, and the
  last one is changed by `fun`. Raises an `ArgumentError` if any of them isn't there, or if a shape
  is asked for something inside it.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><g id="car"><g id="front"><circle id="wheel" r="1"/></g></g></svg>))
      iex> drawing = Curves.Drawing.update_in(drawing, ["car", "wheel"], &Curves.Transform.inc_rotation(&1, 90))
      iex> Curves.Drawing.get_in(drawing, ["car", "front", "wheel"]).rotation
      1.5707963267948966
  """
  @spec update_in(container(), nonempty_list(String.t()), (child() -> child())) :: container()
  def update_in(container, [id], fun), do: update(container, id, fun)

  def update_in(container, [id | path], fun),
    do: update(container, id, &update_inside(&1, id, path, fun))

  @spec update_inside(child(), String.t(), list(String.t()), (child() -> child())) :: child()
  defp update_inside(%Group{} = group, _id, path, fun), do: update_in(group, path, fun)

  defp update_inside(_node, id, _path, _fun) do
    raise ArgumentError, "#{inspect(id)} is a shape, so there is nothing inside it to look for"
  end

  @doc ~s"""
  An `Access` function for the shape or group with this `id`, to use with Elixir's own
  `Kernel.get_in/2`, `Kernel.update_in/3` and `Kernel.pop_in/2` on a drawing.

  `get_in/2` gives `nil` if there is no such id, while `update_in/3` and `pop_in/2` raise an
  `ArgumentError`, like `update/3` and `delete/2`.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><g id="car"><circle id="wheel" r="1"/></g></svg>))
      iex> wheel = Curves.Drawing.by_id("wheel")
      iex> get_in(drawing, [Curves.Drawing.by_id("car"), wheel]).element
      :circle
      iex> drawing = update_in(drawing, [wheel], &Curves.Transform.set_scale(&1, 2))
      iex> Curves.Drawing.get(drawing, "wheel").scale
      2
      iex> {_wheel, drawing} = pop_in(drawing, [wheel])
      iex> Curves.Drawing.get(drawing, "wheel")
      nil
  """
  @spec by_id(String.t()) :: Access.access_fun(container(), child())
  def by_id(id) when is_binary(id) do
    fn
      :get, container, next ->
        next.(get(container, id))

      :get_and_update, container, next ->
        case fetch(container, id) do
          {:ok, node} -> get_and_update(container, id, node, next.(node))
          :error -> raise ArgumentError, "there is no shape or group with the id #{inspect(id)}"
        end
    end
  end

  @spec get_and_update(container(), String.t(), child(), {term(), child()} | :pop) ::
          {term(), container()}
  defp get_and_update(container, id, node, :pop), do: {node, delete(container, id)}
  defp get_and_update(container, id, _node, {value, new}), do: {value, put(container, id, new)}

  ## Changing every part

  @doc ~s"""
  Changes every shape in the drawing (or group), wherever it is, to what `fun` returns for it.
  The shapes are as stored: a group's transform isn't applied to them (see `shapes/1`). `fun` must
  return a shape, group or raw markup; to take shapes out, use `delete/2`.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><circle r="1"/><g><rect width="2" height="1"/></g></svg>))
      iex> drawing = Curves.Drawing.update_shapes(drawing, &put_in(&1.attributes["fill"], "red"))
      iex> drawing |> Curves.Drawing.shapes() |> Enum.map(& &1.attributes["fill"])
      ["red", "red"]
  """
  @spec update_shapes(container(), (Shape.t() -> Shape.t())) :: container()
  def update_shapes(%{children: children} = container, fun),
    do: %{container | children: Enum.map(children, &update_shape(&1, fun))}

  @spec update_shape(child(), (Shape.t() -> Shape.t())) :: child()
  defp update_shape(%Shape{} = shape, fun), do: shape |> fun.() |> one_node()
  defp update_shape(%Group{} = group, fun), do: update_shapes(group, fun)
  defp update_shape(%Raw{} = raw, _fun), do: raw

  @doc ~s"""
  Changes every curve in the drawing (or group, or shape) to what `fun` returns for it, e.g. to
  apply a `Curves.Transform` to each curve on its own.

  ## Examples
      iex> drawing = Curves.from_svg(~s(<svg><path d="M0 0 L4 0"/></svg>))
      iex> drawing = Curves.Drawing.update_curves(drawing, &Curves.Transform.reverse/1)
      iex> drawing |> Curves.Drawing.curves() |> hd() |> Curves.solve!(0.0)
      {4.0, 0.0}
  """
  @spec update_curves(container() | Shape.t(), (Curves.Types.curve_struct() ->
                                                  Curves.Types.curve_struct())) ::
          container() | Shape.t()
  def update_curves(%Shape{subpaths: subpaths} = shape, fun),
    do: %{shape | subpaths: Enum.map(subpaths, &%{&1 | curve: fun.(&1.curve)})}

  def update_curves(%{children: _} = container, fun),
    do: update_shapes(container, &update_curves(&1, fun))
end
