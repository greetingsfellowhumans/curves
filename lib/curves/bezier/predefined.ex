defmodule Curves.Bezier.Predefined do
  @moduledoc ~s"""
  Shortcuts for quickly getting a list of points that can be passed into `Curves.define_bezier/1`

  ## Usage
  ```elixir
      iex> alias Curves.Bezier.Predefined
      iex> Predefined.get_coords(:linear_up_right)
      [{0.0, 0.0}, {1.0, 1.0}]
      iex> [:ease | _] = Predefined.list()
      iex> Predefined.get_coords(:ease_in_out_cubic)
      [{0.0, 0.0}, {0.65, 0.0}, {0.35, 1.0}, {1.0, 1.0}]
  ```
  """
  alias Curves.Types, as: T

  @order1 %{
    linear:              [{0, 0}, {1, 1}],
    linear_up_right:     [{0, 0}, {1, 1}],
    linear_down_right:   [{0, 1}, {1, 0}],
    linear_horizontal:   [{0, 1}, {1, 1}],
    linear_vertical:     [{0, 0}, {0, 1}],
  }
  @order2 %{
    quadratic_up:         [{0, 1}, {0.5, 0}, {1, 1}], # F(x) = x^2
    quadratic_down:       [{0, 0}, {0.5, 1}, {1, 0}], # F(x) = -x^2
    quadratic_left:       [{0, 0}, {1, 0.5}, {0, 1}], # F(x) = -x^2
    quadratic_right:      [{1, 1}, {0, 0.5}, {1, 0}], # F(x) = -x^2
  }
  @order3 %{
    ease:                [{0.3, 0}, {0.65, 0}],
    ease_in:             [{0.3, 0}, {0.65, 0}],
    ease_out:            [{0.35, 1}, {0.7, 1}],
    ease_in_out:         [{0.65, 0}, {0.35, 1}],

    ease_in_back:        [{0.35, 0}, {0.65, -0.55}],
    ease_in_circ:        [{0.6, 0.1}, {0.95, 0.3}],
    ease_in_cubic:       [{0.3, 0}, {0.65, 0}],
    ease_in_expo:        [{0.95, 0.1}, {0.8, 0}],
    ease_in_quad:        [{0.1, 0}, {0.5, 0}],
    ease_in_quart:       [{0.5, 0}, {0.75, 0}],
    ease_in_quint:       [{0.75, 0.1}, {0.85, 0.1}],
    ease_in_sine:        [{0.1, 0}, {0.4, 0}],

    ease_out_back:       [{0.35, 1.55}, {0.65, 1}],
    ease_out_circ:       [{0.1, 0.8}, {0.2, 1.0}],
    ease_out_cubic:      [{0.35, 1}, {0.7, 1}],
    ease_out_expo:       [{0.18, 1.0}, {0.22, 1.0}],
    ease_out_quad:       [{0.5, 1}, {0.9, 1}],
    ease_out_quart:      [{0.25, 1}, {0.5, 1}],
    ease_out_quint:      [{0.2, 1.0}, {0.3, 1}],
    ease_out_sine:       [{0.6, 1}, {0.9, 1}],

    ease_in_out_back:    [{0.70, -0.6}, {0.3, 1.6}],
    ease_in_out_circ:    [{0.79, 0.14}, {0.15, 0.86}],
    ease_in_out_cubic:   [{0.65, 0}, {0.35, 1}],
    ease_in_out_expo:    [{1, 0}, {0, 1}],
    ease_in_out_quad:    [{0.45, 0}, {0.55, 1}],
    ease_in_out_quart:   [{0.75, 0}, {0.25, 1}],
    ease_in_out_quint:   [{0.87, 0}, {0.07, 1}],
    ease_in_out_sine:    [{0.35, 0}, {0.60, 1}],
  } |> Map.new(fn
      {k, [p1, p2]} -> {k, [{0, 0}, p1, p2, {1, 1}]}
      {k, [_p0, _p1, _p2, _p3] = li} -> {k, li}
    end)

  @all @order1
       |> Map.merge(@order2)
       |> Map.merge(@order3)
       |> Map.new(fn {k, li} ->
         {k, Enum.map(li, fn {x, y} -> {x * 1.0, y * 1.0} end)} # Coerce to floats
       end)

  @typedoc ~s"""
  ### Cubic
  `#{Map.keys(@order3) |> Enum.map_join(", ", &(":#{&1}"))}`

  ### Quadratic
  `#{Map.keys(@order2) |> Enum.map_join(", ", &(":#{&1}"))}`

  ### Linear
  `#{Map.keys(@order1) |> Enum.map_join(", ", &(":#{&1}"))}`
  """
  @type curve_key :: atom()

  @typedoc "A list of curve keys"
  @type curve_keys :: list(curve_key())

  @typedoc ~s"""
  A map of useful info about a predefined curve.
  """
  @type curve_type_info :: %{order: T.order(), key: curve_key(), points: T.point_list()}

  @typedoc ~s"""
  A list of curve type info
  """
  @type curve_type_infos :: list(curve_type_info())

  @doc ~s"""
  Return a list of all keys that can be used with `get_coords/1`

  ## Examples
      iex> [:ease | _] = Curves.Bezier.Predefined.list()
  """
  @spec list() :: curve_keys()
  def list(), do: Map.keys(@all) |> Enum.sort()

  @doc ~s"""
  Return a list of all keys, within a given curve order, that can be used with `get_coords/1`
  `(linear = 1, quadratic = 2, cubic = 3)`

  alternately, pass in one of `:linear`, `:quad`, `:cubic`.

  ## Examples
      iex> [:linear | _] = Curves.Bezier.Predefined.list(1)
      iex> [:quadratic_down | _] = Curves.Bezier.Predefined.list(2)
      iex> Curves.Bezier.Predefined.list(:cubic) == Curves.Bezier.Predefined.list(3)
      true
      iex> Curves.Bezier.Predefined.list(:linear) == Curves.Bezier.Predefined.list(1)
      true
      iex> Curves.Bezier.Predefined.list(:quad) == Curves.Bezier.Predefined.list(2)
      true
  """
  @spec list(T.order() | :linear | :quad | :cubic) :: curve_keys()
  def list(order) do
    case order do
      1 -> @order1
      :linear -> @order1

      2 -> @order2
      :quad -> @order2

      3 -> @order3
      :cubic -> @order3

      other ->
        raise ArgumentError,
              "order must be 1, 2, 3, :linear, :quad or :cubic, got: #{inspect(other)}"
    end
      |> Map.keys()
      |> Enum.sort()
  end

  @doc ~s"""
  Return a map with details about a specific curve.

  ## Examples
      iex> Curves.Bezier.Predefined.details(:linear_up_right)
      %{key: :linear_up_right, order: 1, points: [{0.0, 0.0}, {1.0, 1.0}]}
  """
  @spec details(curve_key()) :: curve_type_info()
  def details(k) do
    li = fetch!(k)
    order = Enum.count(li) - 1
    %{key: k, points: li, order: order}
  end

  @doc ~s"""
  Return `details/1` for every predefined curve, sorted by key.

  ## Examples
      iex> [first | _] = Curves.Bezier.Predefined.list_details()
      iex> first
      %{key: :ease, order: 3, points: [{0.0, 0.0}, {0.3, 0.0}, {0.65, 0.0}, {1.0, 1.0}]}
  """
  @spec list_details() :: list(curve_type_info())
  def list_details() do
    list()
      |> Enum.map(&details/1)
  end

  @doc ~s"""
  Return the list of `{x, y}` points for a predefined curve. A name that isn't one raises an `ArgumentError`.

  ## Examples
      iex> Curves.Bezier.Predefined.get_coords(:linear_up_right)
      [{0.0, 0.0}, {1.0, 1.0}]
      iex> Curves.Bezier.Predefined.get_coords(:nope)
      ** (ArgumentError) unknown predefined curve: :nope. See Curves.Bezier.Predefined.list/0 for the names
  """
  @spec get_coords(curve_key()) :: T.point_list()
  def get_coords(k), do: fetch!(k)

  @doc false
  @spec get(curve_key(), T.opts()) :: T.point_list()
  def get(k, _opts \\ []) do
    fetch!(k) |> Enum.map(&Curves.Utils.Vec.new/1)
  end

  # The points of a predefined curve, or a clear error when `k` isn't one of the names.
  @spec fetch!(term()) :: T.point_list()
  defp fetch!(k) when is_map_key(@all, k), do: Map.fetch!(@all, k)

  defp fetch!(k) do
    raise ArgumentError,
          "unknown predefined curve: #{inspect(k)}. See Curves.Bezier.Predefined.list/0 for the names"
  end

end
