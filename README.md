# Curves

## Introduction

Curves aims to be the best elixir framework for calculating bezier curves and splines.

```elixir
curve = Curves.define_bezier(:ease_out)
{x, y} = Curves.solve!(curve, 0.25)
assert is_float(x)
assert is_float(y)
```

## Directory

Be sure to check out the [livebook](https://curves.hexdocs.pm/bezier_curves.html) for an interactive demo/tutorial.

- [Hex docs](https://curves.hexdocs.pm/)
- [Hex package](https://hex.pm/packages/curves)
- [Github Repo](https://github.com/greetingsfellowhumans/curves)

## Hire me

No AI was used in the creation of this project. Just good old fashioned software engineering.

Full stack developer seeking new challenges. You can reach me at [hireme@aaronjprice.com](mailto:hireme@aaronjprice.com)

## Visual Demo

### Ease in-out Bezier

The simplest way to use Curves is with the predefined ones like `:ease_in_out`

```elixir
curves = Curves.define_bezier(:ease_in_out)
for i <- 0..1000 do
  Curves.solve!(curve, i / 1000)
end
|> # render_vega_lite_chart(...)
```

![Ease In Out](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/ease_in_out.png)

### Quadratic Bezier

Here we make an asymmetric quadratic curve

```elixir
points = [
  {0, 0},
  {20, 50},
  {100, 0}
]
curves = Curves.define_bezier(points)
```

![Quadratic](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/quadratic.png)

### Custom 4-point Bezier

```elixir
points = [
  {0, 0},
  {0.8, 0.2},
  {0.3, 2.2},
  {1, 1}
]
curves = Curves.define_bezier(points)
```

![Custom Bezier](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/custom_bezier.png)

## Spline examples

The simplest spline is basically just a series of bezier curves connected to each other.
Notice we are no longer using `define_bezier`, but `define_bezier_spline`. Now it is a list of lists with 1, 2, or 3 tuples in each segment.

```elixir
# points format for `define_bezier_spline/2`
[{knot_x, knot_y}]
[{knot_x, knot_y}, {cp0_x, cp0_y}]
[{knot_x, knot_y}, {cp0_x, cp0_y}, {cp1_x, cp1_y}]
```

### Bezier Spline

```elixir
points = [
  # P0
  [{5.0, 10.0},  # Knot
  {10.0, 10.0}], # control point 0

  # P1
  [{10.0, 5.0},  # Knot
    {5.0, 5.0},  # control point 0
    {15.0, 5.0}],# control point 1

  # P2
  [{15.0, 10.0}, # Knot
   {15.0, 6.0},  # control point 0
   {15.0, 14.0}  # control point 1
  ],

  # P3
  [{20.0, 15.0}, # Knot
   {18.0, 15.0}, # control point 0
   {23.0, 15.0}],# control point 1

  # P4
  [{30.0, 10.0}, # Knot
    {32.0, 5.0}] # control point 0
]
curves = Curves.define_bezier_spline(points)
```

![Bezier Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/bezier_spline.png)

### Cubic Hermite Spline

Sometimes we don't want to manually define every control point.
The Hermite spline automatically calculates it based on the first derivative at the start and end point of each segment.

```elixir
curve = Curves.define_hermite([
  {5, 10},
  {10, 5},
  {15, 10},
  {20, 10},
  {25, 5},
  {30, 15},
])
```

![Hermite Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/hermite.png)

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

![Catmull-Rom Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/catmull_rom.png)

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

![B-Spline](https://github.com/greetingsfellowhumans/curves/raw/main/assets/examples/b_spline.png)
