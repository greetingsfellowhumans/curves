# Curves

## Introduction

Curves aims to be the best elixir framework for calculating bezier curves and splines.

## Installation

```elixir
def deps do
  [
    {:curves, "~> 0.1.0"},
  ]
end
```

## Directory

Welcome to Curves!
Be sure to check out the Livebook in the github repo for an interactive demo.

- [Hex docs](https://curves.hexdocs.pm/)
- [Hex package](https://hex.pm/packages/curves)
- [Github Repo](https://github.com/greetingsfellowhumans/curves)

## Usage

The basic cycle goes like this:

1. start with a list of `{x, y}` tuples. These can be any combination of integers and floats.
2. build a `Curves.Curve` struct by passing the list of tuples into `Curves.define_curve/2`
3. To find a point in the curve struct, call `Curves.solve/3` with a float (0.0 - 1.0)

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

{x, y} == {0.1280975341796875, 0.28279876708984375}
```

## A note about performance

We use the [Nx](https://nx.hexdocs.pm/installation.html#installing-nx-with-exla-for-gpu-acceleration) library under the hood, so you should should follow their instructions
for setting up a GPU backend. Otherwise, it will still work fine, just not as blazing fast.

## Current state

This project is under active development and evolving rapidly. Pull requests and issues are welcome. I am very approachable if you have any questions, quandries, queries, quagmires, or other aliteration.

It is possible there will be breaking changes in the future - at least until a v1 is released.

There are also many features planned that are still a WIP. For example splines, more utility functions for working with curves.
