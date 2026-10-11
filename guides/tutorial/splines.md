# 3. Splines

> Prefer to play? This chapter is also an [interactive Livebook](../livebooks/03_splines.livemd) where you move knots,
> switch spline types and bend tangents with sliders.

A spline joins several curves end to end into one smooth path. Each piece is called a **segment**, and the
points where segments meet are called **knots**.

## `u`: which segment, and how far along it

On a single Bezier curve, `t` goes from `0.0` to `1.0`. On a spline, you use `u`, and **each segment adds
one to it**: `u = 0.0` to `1.0` is the first segment, `1.0` to `2.0` the second, and so on. Whole numbers
land exactly on the knots. `Curves.max_u/1` tells you where the spline ends:

```elixir
curve = Curves.define_catmull_rom([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])
Curves.max_u(curve)
#=> 4.0
Curves.solve!(curve, 2.0)
#=> {4.0, 1.0}
```

![u = 0, 1, 2, 3 and 4 land on the knots](images/spline_u.svg)

`Curves.take!/2` works the same way: it spreads its points over the whole spline.

## Four kinds of spline

They all join curves together, but they differ in what you give them and how they bend.

### Catmull-Rom: through every knot, no extra work

Give it the knots, and it works out the bends for you. The curve passes through every knot. This is the
easiest spline to use.

```elixir
Curves.define_catmull_rom([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])
```

### B-spline: the smoothest, but only near the knots

A B-spline is even smoother, but it does **not** pass through your knots: it is pulled towards them, and
it only covers the middle part (`n` knots give `n - 3` segments). It needs at least 4 knots.

```elixir
Curves.define_b_spline([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])
```

| Same knots (purple), two splines | |
| --- | --- |
| ![Catmull-Rom](images/spline_catmull_rom.svg) | ![B-spline](images/spline_b_spline.svg) |

### Bezier spline: you control every bend

A chain of Bezier curves, written like an SVG path. Each point is a knot, followed by the control points of
the curve **to the next knot**:

| Point | The curve to the next knot | Like SVG's |
| --- | --- | --- |
| `[knot]` | a straight line | `L` |
| `[knot, c]` | a quadratic curve, pulled towards `c` | `Q` |
| `[knot, c0, c1]` | a cubic curve: leaves `knot` towards `c0`, arrives from `c1` | `C` |

The last point only ends the curve, so it is just `[knot]`.

```elixir
Curves.define_bezier_spline([
  [{0, 0}],                       # a straight line to {3, 2}
  [{3, 2}, {4.5, 5}],             # a quadratic curve to {6, 2}
  [{6, 2}, {7, 0}, {9, 5}],       # a cubic curve to {10, 2}
  [{10, 2}]                       # the end
])
```

![L, then Q, then C](images/spline_bezier_lqc.svg)

### Hermite: say which way to go

A Hermite spline passes through every knot, and at each knot you give a **tangent**: the direction the
curve travels, and how fast. A longer tangent makes the curve keep its direction for longer before it
turns. Here only the middle tangent changes:

```elixir
Curves.define_hermite([
  [{0, 0}, {4, 0}],    # [knot, tangent]
  [{4, 2}, {2, 0}],    # try {12, 0} here
  [{8, 0}, {4, 0}]
])
```

| `{2, 0}` | `{12, 0}` |
| --- | --- |
| ![Short tangent](images/spline_hermite_short.svg) | ![Long tangent](images/spline_hermite_long.svg) |

Catmull-Rom is a Hermite spline that works out the tangents for you.

## Which one should I use?

| You want... | Use |
| --- | --- |
| a smooth path through some points, quickly | `define_catmull_rom/2` |
| the smoothest possible path, and don't need to hit the points exactly | `define_b_spline/2` |
| exact control over every bend, or to copy an SVG path | `define_bezier_spline/2` |
| to set the direction and speed at each point | `define_hermite/2` |

**Next:** [Transforms and drawing](transforms.md).
