defmodule Curves.Bezier.Predefined do
  @moduledoc false
  import Curves.Utils.Points, only: [new_points: 2]


  @all %{
    ease: [{0.3, 0}, {0.65, 0}],
    ease_in: [{0.3, 0}, {0.65, 0}],
    ease_out: [{0.35, 1}, {0.7, 1}],
    ease_in_out: [{0.65, 0}, {0.35, 1}],

    ease_in_back: [{0.35, 0}, {0.65, -0.55}],
    ease_in_circ: [{0.6, 0.1}, {0.95, 0.3}],
    ease_in_cubic: [{0.3, 0}, {0.65, 0}],
    ease_in_expo: [{0.95, 0.1}, {0.8, 0}],
    ease_in_quad: [{0.1, 0}, {0.5, 0}],
    ease_in_quart: [{0.5, 0}, {0.75, 0}],
    ease_in_quint: [{0.75, 0.1}, {0.85, 0.1}],
    ease_in_sine: [{0.1, 0}, {0.4, 0}],

    ease_out_back: [{0.35, 1.55}, {0.65, 1}],
    ease_out_circ: [{0.1, 0.8}, {0.2, 1.0}],
    ease_out_cubic: [{0.35, 1}, {0.7, 1}],
    ease_out_expo: [{0.18, 1.0}, {0.22, 1.0}],
    ease_out_quad: [{0.5, 1}, {0.9, 1}],
    ease_out_quart: [{0.25, 1}, {0.5, 1}],
    ease_out_quint: [{0.2, 1.0}, {0.3, 1}],
    ease_out_sine: [{0.6, 1}, {0.9, 1}],

    ease_in_out_back: [{0.70, -0.6}, {0.3, 1.6}],
    ease_in_out_circ: [{0.79, 0.14}, {0.15, 0.86}],
    ease_in_out_cubic: [{0.65, 0}, {0.35, 1}],
    ease_in_out_expo: [{1, 0}, {0, 1}],
    ease_in_out_quad: [{0.45, 0}, {0.55, 1}],
    ease_in_out_quart: [{0.75, 0}, {0.25, 1}],
    ease_in_out_quint: [{0.87, 0}, {0.07, 1}],
    ease_in_out_sine: [{0.35, 0}, {0.60, 1}],
  }

  def list(), do: Map.keys(@all)

  def get(k), do: get(k, [])
  def get(:linear, opts), do: new_points([{0, 0.5}, {0.2, 0.5}, {0.8, 0.5}, {1, 0.5}], opts)
  def get(:linear_upward, opts), do: new_points([{0, 0}, {0.2, 0.2}, {0.8, 0.8}, {1, 1}], opts)
  def get(:linear_downward, opts), do: new_points([{0, 1}, {0.2, 0.8}, {0.8, 0.2}, {1, 0}], opts)
  def get(k, opts) do
    [{x1, y1}, {x2, y2}] = Map.get(@all, k)
    new_points([
      {0, 0},
      {x1, y1},
      {x2, y2},
      {1, 1}
    ], opts)

  end


end
