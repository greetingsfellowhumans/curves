# 3. Splines

> Prefer to play? This chapter is also an [interactive Livebook](../livebooks/03_splines.livemd) where you move knots,
> switch spline types, bend tangents and turn the dials with sliders.

A spline joins several curves end to end into one smooth path. Each piece is called a **segment**, and the
points where segments meet are called **knots**. This chapter also covers the simplest path of all, the
polyline, which joins the knots with straight lines.

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

## The simplest path: a polyline

A polyline just joins the knots with straight lines, like SVG's `<polyline>`. It isn't a spline (nothing
bends), but you move along it with `u` in exactly the same way, and at a steady speed along each line:
`u = 1.5` is halfway between the second and third knots.

```elixir
curve = Curves.define_polyline([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])
Curves.solve!(curve, 1.5)
#=> {3.0, 2.0}
```

![A polyline](images/polyline.svg)

## Kinds of spline

Curves has nine kinds of spline. They all join curves together, but they differ in what you give them
and how they bend. Here are the first four; the other five are variations on Catmull-Rom, below.

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

Catmull-Rom is a Hermite spline that works out the tangents for you. So are the next five: each one is
a different recipe for the tangents. Like Catmull-Rom, you only give them the knots, and they pass
through every one.

### Cardinal: Catmull-Rom with a tension slider

`:tension` pulls the curve tighter at each knot. `0.0` (the default) is exactly Catmull-Rom, and `1.0`
gives straight lines.

```elixir
Curves.define_cardinal([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}], tension: 0.5)
```

![Cardinal, tension 0.5](images/spline_cardinal.svg)

### Centripetal Catmull-Rom: no loops

When some knots are much closer together than others, plain Catmull-Rom can overshoot and even make a
little loop. The centripetal version takes the distances between the knots into account, and never
loops. If you just want a smooth path through some points, this is a great default.

```elixir
Curves.define_centripetal_catmull_rom([{0, 0}, {10, 10}, {10.5, 10}, {20, 0}])
```

| Plain Catmull-Rom | Centripetal |
| --- | --- |
| ![A little loop](images/spline_bunched_catmull_rom.svg) | ![No loop](images/spline_centripetal.svg) |

### Kochanek-Bartels: three dials

Also called a TCB spline, after its three dials: `:tension` (like the cardinal spline's), `:continuity`
(sharp corners or bulges at the knots) and `:bias` (turn early, or late and overshoot). Animation tools use
it for keyframes. With all three at `0.0`, it's Catmull-Rom.

```elixir
Curves.define_kochanek_bartels([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}], bias: 0.5)
```

![Kochanek-Bartels, bias 0.5](images/spline_kochanek_bartels.svg)

### Monotone: for charts

The other splines can swing above or below your points. That's bad for a chart: it shows peaks and dips
that aren't in the data. A monotone spline never overshoots: between two knots it only goes up, only goes
down, or stays flat. Each knot is a data point, so each `x` must be bigger than the one before.

```elixir
Curves.define_monotone([{0, 2}, {1, 2}, {2, 2}, {3, 8}, {4, 8.5}, {5, 3}, {6, 3}])
```

| Catmull-Rom | Monotone |
| --- | --- |
| ![Overshoots](images/spline_data_catmull_rom.svg) | ![Never overshoots](images/spline_monotone.svg) |

### Natural cubic: the smoothest through every knot

A B-spline is smooth because even how sharply it bends changes gradually, but it misses your knots. A
natural cubic spline is that smooth *and* goes through every knot. The catch: each knot affects the whole
curve, so moving one changes everything a little.

```elixir
Curves.define_natural_cubic([{0, 0}, {2, 3}, {4, 1}, {6, 4}, {8, 2}])
```

![Natural cubic](images/spline_natural_cubic.svg)

## Which one should I use?

| You want... | Use |
| --- | --- |
| straight lines between your points | `define_polyline/2` |
| a smooth path through some points, quickly | `define_centripetal_catmull_rom/2` |
| the classic Catmull-Rom spline | `define_catmull_rom/2` |
| to choose how tightly it bends | `define_cardinal/2` or `define_kochanek_bartels/2` |
| a smooth line through chart data, without made-up peaks | `define_monotone/2` |
| the smoothest path that still hits every point | `define_natural_cubic/2` |
| the smoothest possible path, and don't need to hit the points exactly | `define_b_spline/2` |
| exact control over every bend, or to copy an SVG path | `define_bezier_spline/2` |
| to set the direction and speed at each point | `define_hermite/2` |

[Choosing a curve](../choosing_a_curve.md) compares them all side by side, with real-world examples of each.

**Next:** [Transforms and drawing](transforms.md).
