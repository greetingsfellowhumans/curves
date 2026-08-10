defmodule Curves do
  @moduledoc """
  ## Introduction
  Welcome to Curves!
  Be sure to check out the Livebook in the github repo for an interactive demo. 

  ## Usage
  The basic cycle goes like this:
  1. start with a list of `{x, y}` tuples. These can be any combination of integers and floats.
  2. build a `Curves.Curve` struct by passing the list of tuples into `Curves.define_curve/2`
  3. To find a point in the curve struct, call `Curves.solve/3` with a float (0.0 - 1.0) 

  For example:
  ```elixir
  curve = Curves.define_curve([
  # {x,   y}
    {0,   0},
    {0,   0.5},
    {0.8, 0.4},
    {1,   1}
  ])

  t = 0.25 # i.e. 25% from beginning to end of the curve.

  {x, y} = Curves.solve!(curve, t)

  {0.1280975341796875, 0.28279876708984375} = {x, y}
  ```

  ## A note about performance
  We use the `Nx` library under the hood, so you should should follow their instructions
  for setting up a GPU backend. Otherwise, it will still work fine, just not as blazing fast.

  ## Current state
  This project is under active development and evolving rapidly. Pull requests and issues are welcome. I am very approachable if you have any questions, quandries, queries, quagmires, or other aliteration.

  It is possible there will be breaking changes in the future - at least until a v1 is released.

  There are also many features planned that are still a WIP. For example splines, more utility functions for working with curves.
  """


  @doc ~s"""
  Build a new Bezier Curve struct.

  ## Examples
      iex> c = Curves.define_curve([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> is_struct(c, Curves.Curve)
      true
  """
  defdelegate define_curve(points, opts \\ []), to: Curves.Bezier.Curve, as: :define


  @doc ~s"""
  Given a struct, and t, find the point along the curve

  ## Examples
      iex> c = Curves.define_curve([{0.1, 0.9}, {0.5, 0.9}, {0.5, 0.1}, {0.75, 0.1}])
      iex> Curves.solve(c, 0.3)
      {0.3695499897003174, 0.727199912071228}

  ## Options
  * `:float_dtype` (default: nil) | If set to an integer, passes results to Float.round(_, precision)

  """
  defdelegate solve(curve, t, opts \\ []), to: Curves.Bezier.Curve
  defdelegate solve!(curve, t, opts \\ []), to: Curves.Bezier.Curve

end
