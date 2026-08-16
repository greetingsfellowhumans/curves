defmodule Curves.Bezier.Predefined do
  @moduledoc false


  @all %{
    ease_in_sine: [{0.1, 0}, {0.4, 0}],
    ease_in_quad: [{0.1, 0}, {0.5, 0}],
    ease_in_cubic: [{0.3, 0}, {0.65, 0}],
    ease_in_quart: [{0.5, 0}, {0.75, 0}],
    ease_in_elastic: [{0.35, 0}, {0.65, -0.55}],
    ease_out_sine: [{0.6, 1}, {0.9, 1}],
    ease_out_quad: [{0.5, 1}, {0.9, 1}],
    ease_out_cubic: [{0.35, 1}, {0.7, 1}],
    ease_out_quart: [{0.25, 1}, {0.5, 1}],
    ease_out_elastic: [{0.35, 1.55}, {0.65, 1}],
    ease_in_out_sine: [{0.35, 0}, {0.60, 1}],
    ease_in_out_quad: [{0.45, 0}, {0.55, 1}],
    ease_in_out_cubic: [{0.65, 0}, {0.35, 1}],
    ease_in_out_quart: [{0.75, 0}, {0.25, 1}],
    ease_in_out_elastic: [{0.70, -0.6}, {0.3, 1.6}],
  }


  def get(k, _opts \\ []) do
    [{x1, y1}, {x2, y2}] = Map.get(@all, k)
    Curves.Utils.Points.new_points([
      {0, 0},
      {x1, y1},
      {x2, y2},
      {1, 1}
    ])

  end


end
