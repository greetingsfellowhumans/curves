# Upgrading from 0.2.x to 1.0

Version 1.0 makes the API stable: after 1.0.0, breaking changes wait for 2.0.
To get there, a few things changed from 0.2.x. Most code only needs the steps in sections 1 to 4,
plus section 10 if you use bezier splines and section 11 if you scale curves that you also move.
Each section shows the old code, then the 1.0 code.

```elixir
# mix.exs
def deps do
  [
    {:curves, "~> 1.0.0-rc.2"}
  ]
end
```

### Coming from 1.0.0-rc.1

Three breaking changes landed in 1.0.0-rc.2:

- [Section 10](#10-bezier-spline-points-are-svg-style): bezier spline points are SVG-style. Convert your points.
- [Section 11](#11-scaling-no-longer-moves-a-curve): scaling no longer moves a curve.
- [Section 12](#12-predefined-get_coords-1-raises-for-an-unknown-name): `Predefined.get_coords/1` raises for an unknown name.

`Curves.Svg` also draws an axes grid by default now (`show_axes: false` turns it off), and invalid input raises
clearer `ArgumentError`s. See the [changelog](changelog.html).

## 1. No more Nx: results are plain 64-bit floats

1.0 calculates with Elixir's own floats instead of Nx tensors, which makes it much faster and leaves
Curves with no runtime dependencies. Results are 64-bit (0.2.x used 16-bit by default), so they're more
precise and differ slightly from 0.2.x in their last digits.

- Remove `:float_dtype` from your options and config. It no longer exists; passing it has no effect.
- If you only added Nx for Curves, you can remove it from your dependencies.
- Compare results with a small tolerance rather than exact equality: the exact last digits are not part of the API.

```elixir
# 1.0
{x, y} = Curves.solve!(Curves.define_bezier(:linear), 0.5)
true = is_float(x) and is_float(y)
```

## 2. Drawing curves: `Curves.Utils.Plotting` is gone

0.2.x turned a curve into points for VegaLite/Tucan. 1.0 draws an SVG directly with `Curves.Svg`, with no extra dependencies.

```elixir
# 0.2.x
curve = Curves.define_bezier(:ease_in_out)

curve
|> Curves.Utils.Plotting.curve_to_scatterplot(count: 300)
|> Tucan.scatter("x", "y")
```

```elixir
# 1.0
curve = Curves.define_bezier(:ease_in_out)

path = Path.join(System.tmp_dir!(), "ease_in_out.svg")
Curves.Svg.save!(curve, path, samples: 300, title: "Ease in-out")
```

In Livebook, show it with Kino: `curve |> Curves.Svg.render() |> Kino.Image.new(:svg)`.
Swap the `tucan`, `vega_lite` and `kino_vega_lite` dependencies for `{:kino, "~> 0.19"}`.

## 3. Out-of-bounds errors include the value

`Curves.solve/3` on a spline now reports the `u` it was given, the same shape beziers use:

```elixir
# 0.2.x
{:error, :out_of_bounds} = Curves.solve(spline, 99.0)
```

```elixir
# 1.0
{:error, {:out_of_bounds, 99.0}} = Curves.solve(spline, 99.0)
```

The exceptions raised by `solve!/3` and `take!/3` now carry their values too, e.g. `OutOfBoundU` has `u` and `max`.

## 4. Use `Curves.max_u/1` instead of `curve.max_u`

The curve structs are now opaque: their fields are internal and may change in any 1.x release.
Use the functions in `Curves` instead of reading fields.

```elixir
# 0.2.x
last_u = spline.max_u
```

```elixir
# 1.0
last_u = Curves.max_u(spline)
```

## 5. Typespecs moved out of `Curves.Utils`

If your own `@spec`s use the library's types, update the module names:

| 0.2.x | 1.0 |
| --- | --- |
| `Curves.Utils.Types.point_tuple()`, `.opts()`, … | `Curves.Types.point_tuple()`, `.opts()`, … |
| `Curves.Utils.Types.point()` (a tensor) | removed; points are `Curves.Types.point_tuple()` |
| `Curves.Utils.Types.points()` (a tensor) | removed; use `Curves.Types.point_list()` |
| `Curves.Utils.Types.point_names()` | removed (no more tensor axis names) |

## 6. `:force_percent` changes

If you use `force_percent: true`, these may change your results:

- **It now works everywhere.** In 0.2.x, beziers only honoured it when passed to `solve/3`/`take/3`, and splines ignored it there. Now it's honoured when passed to `define_*`, `solve/3` or `take/3`, or set in the app config, for both.
- **Moved, scaled and rotated curves** are rescaled using their position *after* the transforms (including the `:origin` option), so they return values between `0.0` and `1.0`. In 0.2.x they could return values far outside that range.
- **A flat axis** (every point has the same value on it) now returns `0.5` instead of its raw value.
- **The app config is read on every call** (`solve`/`take`), for splines as well as beziers. Changing it while running applies to existing curves straight away.

```elixir
# 1.0
curve = Curves.define_bezier(:linear_horizontal)
{0.5, 0.5} = Curves.solve!(curve, 0.5, force_percent: true)
```

## 7. B-splines run in order

In 0.2.x, B-spline segments were solved in reverse order, so the curve jumped between segments as `u` increased.
They now run from start to end. The overall shape is the same, but `solve/3` returns different points for the same `u`.
If you worked around the old order, remove the workaround.

## 8. Beziers with the wrong number of points

A bezier needs 2 to 4 points.

- **More than 4 points** used to return raw tensors from `solve/3`. Now it returns `{:error, {:too_many_points, n, 4}}`, and `solve!/3` raises `Curves.Exceptions.TooManyPoints`. Use a spline, e.g. `Curves.define_bezier_spline/2`, for longer paths.
- **Fewer than 2 points** used to crash in `define_bezier/2`. Now the curve can be defined and transformed, and solving it returns `{:error, {:too_few_points, n, 2}}`.

```elixir
# 1.0
curve = Curves.define_bezier([{0, 0}, {1, 1}, {2, 0}, {3, 1}, {4, 0}])
{:error, {:too_many_points, 5, 4}} = Curves.solve(curve, 0.5)
```

## 9. Hermite splines take tangents

`define_hermite/2` is now a true cubic Hermite spline: give each knot together with its tangent,
the direction (and speed) the curve leaves it with. The 0.2.x version took bare knots, guessed the
slopes, and didn't actually pass through its knots.

```elixir
# 0.2.x
Curves.define_hermite([{0, 0}, {2, 2}, {4, 0}])
```

```elixir
# 1.0
curve = Curves.define_hermite([[{0, 0}, {4, 0}], [{2, 2}, {0, 4}], [{4, 0}, {4, 0}]])
{2.0, 2.0} = Curves.solve!(curve, 1.0)
```

If you want the tangents worked out for you, `define_catmull_rom/2` takes bare knots and is
exactly a Hermite spline with automatic tangents.

## 10. Bezier spline points are SVG-style

Each point of `define_bezier_spline/2` used to be a knot with the two handles *of that knot*:
the control point the curve arrives from, and the one it leaves towards. Now each point works like a
command in an SVG path (or `bezierCurveTo` on a canvas): a knot, then the control points of the curve
from that knot *to the next one*.

| Point | Curve to the next knot | SVG |
| --- | --- | --- |
| `[knot]` | a straight line | `L` |
| `[knot, c]` | a quadratic curve | `Q` |
| `[knot, c0, c1]` | a cubic curve | `C` |

The last point only ends the curve, so it must be `[knot]`. Control points there raise an `ArgumentError`,
which catches most old data. **Old points without control points on the last knot still work, but draw a
different curve,** so convert every bezier spline. This function turns old points into new ones that draw
exactly the same curve:

```elixir
# 0.2.x / 1.0.0-rc.1 points -> 1.0.0-rc.2 points
def to_svg_style(points) do
  points
  |> Enum.chunk_every(2, 1)
  |> Enum.map(fn
    [[knot | _] = point, next] -> [knot, leaving(point), arriving(next)]
    [[knot | _]] -> [knot]
  end)
end

# The control point the old format left a knot towards, and the one it arrived from.
defp leaving([knot]), do: knot
defp leaving([_knot, c]), do: c
defp leaving([_knot, _arrive, leave]), do: leave

defp arriving([knot]), do: knot
defp arriving([_knot, c]), do: c
defp arriving([_knot, arrive, _leave]), do: arrive
```

```elixir
# 1.0.0-rc.1
Curves.define_bezier_spline([
  [{5.0, 10.0}, {10.0, 10.0}],
  [{10.0, 5.0}, {5.0, 5.0}, {15.0, 5.0}],
  [{30.0, 10.0}, {32.0, 5.0}]
])
```

```elixir
# 1.0.0-rc.2: the same curve
Curves.define_bezier_spline([
  [{5.0, 10.0}, {10.0, 10.0}, {5.0, 5.0}],
  [{10.0, 5.0}, {15.0, 5.0}, {32.0, 5.0}],
  [{30.0, 10.0}]
])
```

`Curves.Svg` now draws the dashed lines of beziers and bezier splines from each control point to the knot it
pulls on, instead of one line through all the points.

## 11. Scaling no longer moves a curve

Transforms now apply in the usual scale, rotate, move order (like SVG's
`transform="translate(…) rotate(…) scale(…)"`): the curve is scaled and rotated around its own `{0, 0}`, then moved to
its position. Before, the position was scaled too, so scaling a moved curve also moved it, and a rotation then turned it
around a point that was no longer on the curve. Curves that are moved (`:origin`, `set_position/2`, `inc_position/2`,
`inc_x/2`, `inc_y/2`) *and* scaled give different results; others are unchanged.

```elixir
curve = Curves.define_bezier([{0, 0}, {4, 0}]) |> Curves.Transform.set_position({10, 10})
curve = Curves.Transform.set_scale(curve, 2)

# 1.0.0-rc.1: the position was scaled too
{20.0, 20.0} = Curves.solve!(curve, 0.0)

# 1.0.0-rc.2: the curve stays where it was put
{10.0, 10.0} = Curves.solve!(curve, 0.0)
```

To get an old result back, change the position you set. For a position `{x, y}` and a scale `s`:

- Without rotation, use `{x * s, y * s}`.
- With a rotation too, use `{x, y}` plus the point `{x * s - x, y * s - y}` rotated by the same angle around `{0, 0}`.

## 12. `Predefined.get_coords/1` raises for an unknown name

`Curves.Bezier.Predefined.get_coords/1` used to return `nil` for a name that isn't a predefined curve. Now it raises an
`ArgumentError`, like `details/1` and `define_bezier/2` do. If you checked for `nil`, check the name against
`Curves.Bezier.Predefined.list/0` first instead.

```elixir
# 1.0.0-rc.1
nil = Curves.Bezier.Predefined.get_coords(:nope)

# 1.0.0-rc.2
name = :nope
if name in Curves.Bezier.Predefined.list(), do: Curves.Bezier.Predefined.get_coords(name)
```

## Everything else

Everything else is either new or a bug fix that doesn't need code changes. See the [changelog](changelog.html) for the full list.
