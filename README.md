# Curves

## Introduction

Curves aims to be the best elixir framework for calculating bezier curves and splines.

```elixir
curve = Curves.define_bezier(:ease_out)
        |> Curves.Transform.set_scale(1.5)
        |> Curves.Transform.inc_position({10, 10})
        |> Curves.Transform.set_rotation(90)

# x and y are floats
{x, y} = Curves.solve!(curve, 0.25)
```

## Installation

Add `curves` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:curves, "~> 1.0.0-rc.2"}
  ]
end
```

## Directory

- [Upgrading from 0.2.x to 1.0](https://github.com/greetingsfellowhumans/curves/blob/main/guides/upgrading.md)
- [Bezier Curves Livebook](https://github.com/greetingsfellowhumans/curves/blob/main/guides/bezier_curves.livemd)
- [Splines Livebook](https://github.com/greetingsfellowhumans/curves/blob/main/guides/splines.livemd)
- [Hex docs](https://curves.hexdocs.pm/)
- [Hex package](https://hex.pm/packages/curves)
- [Github Repo](https://github.com/greetingsfellowhumans/curves)

## Hire me

Full stack developer seeking new challenges. You can reach me at [hireme@aaronjprice.com](mailto:hireme@aaronjprice.com)

## Visual Demo

### Ease in-out Bezier

The simplest way to use Curves is with the predefined ones like `:ease_in_out`

```elixir
curve = Curves.define_bezier(:ease_in_out)

# Find any point along the curve (t goes from 0.0 to 1.0)...
Curves.solve!(curve, 0.25)

# ...or draw the whole curve as an SVG image
Curves.Svg.save!(curve, "ease_in_out.svg")
```

![Ease In Out](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/ease_in_out.svg)

### Quadratic Bezier

Here we make an asymmetric quadratic curve

```elixir
points = [
  {0, 0},
  {20, 50},
  {100, 0}
]
curve = Curves.define_bezier(points)
```

![Quadratic](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/quadratic.svg)

### Custom 4-point Bezier

```elixir
points = [
  {0, 0},
  {0.8, 0.2},
  {0.3, 2.2},
  {1, 1}
]
curve = Curves.define_bezier(points)
```

![Custom Bezier](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/custom_bezier.svg)

## Spline examples

The simplest spline is a chain of bezier curves, each one starting where the last one ended.
Notice we are no longer using `define_bezier`, but `define_bezier_spline`. Each point is a list: a knot, then the control points of the curve from that knot to the next one,
just like the commands in an SVG path (or `bezierCurveTo` on a canvas):

| Point | Curve to the next knot | SVG |
| --- | --- | --- |
| `[knot]` | a straight line | `L` |
| `[knot, c]` | a quadratic curve pulled towards `c` | `Q` |
| `[knot, c0, c1]` | a cubic curve: leaves `knot` towards `c0`, arrives at the next knot from `c1` | `C` |

The last point only ends the curve, so it must be `[knot]`.

### Bezier Spline

```elixir
points = [
  # Each point: a knot, then the control points of the curve to the next knot.
  [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],    # cubic to {10, 5}   (SVG C)
  [{10.0, 5.0}, {15.0, 5.0}, {15.0, 6.0}],    # cubic to {15, 10}
  [{15.0, 10.0}, {15.0, 14.0}, {18.0, 15.0}], # cubic to {20, 15}
  [{20.0, 15.0}, {23.0, 15.0}, {32.0, 5.0}],  # cubic to {30, 10}
  [{30.0, 10.0}]                              # the last knot only ends the curve
]
curve = Curves.define_bezier_spline(points)
```

![Bezier Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/bezier_spline.svg)

### Cubic Hermite Spline

A smooth curve through every knot. At each knot you give a tangent: the direction (and speed) the curve leaves it with.

```elixir
curve = Curves.define_hermite([
  # [knot, tangent]
  [{5, 10}, {5, -5}],
  [{10, 5}, {5, 0}],
  [{15, 10}, {5, 5}],
  [{20, 10}, {5, -3}],
  [{25, 5}, {5, 5}],
  [{30, 15}, {5, 10}]
])
```

![Hermite Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/hermite.svg)

### Catmull-Rom Spline

Similar to the Hermite spline, but now the derivative comes from the slope between the previous and next point.

```elixir
curve = Curves.define_catmull_rom([
  {0, 0},
  {1, 0},
  {1, 1},
  {0, 1},
  {0, 2},
  {1, 2},
])
```

![Catmull-Rom Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/catmull_rom.svg)

### B-Spline

The smoothest of the splines featured here, but with the drawback that the line does not actually pass through the control points.

```elixir
curve = Curves.define_b_spline([
    {0, -2},
    {3, 4},
    {6, 5},
    {7, -1},
    {10, 3},
    {5, 1},
    {12, 9}
])
```

![B-Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/b_spline.svg)

## Benchmarks

Benchmarks live in `bench/` and use [Benchee](https://github.com/bencheeorg/benchee). Run them all with:

```sh
mix bench
```

To check a change for slowdowns, save a run before the change, then run again afterwards. A run without a tag is compared against every saved run.

```sh
mix bench baseline           # save this run under the tag "baseline"
mix run bench/solve.exs      # later: run one script and compare it to the saved runs
```

Saved runs go in `bench/results/`, which is not committed. Only compare runs from the same machine.
