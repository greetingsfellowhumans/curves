# Upgrading from 0.2.x to 1.0

```elixir
{:curves, "~> 1.0.0-rc.2"}
```

## Why upgrade

- **40–200× faster**, with no dependencies: Nx is gone, and results are 64-bit floats.
- **Correct**: Hermite splines pass through their knots, B-splines run in order, `:force_percent` works
  everywhere, and bad input raises a clear `ArgumentError`.
- **Stable**: after 1.0.0, breaking changes wait for 2.0.
- **More**: polylines, nine kinds of spline, exact arcs and ellipses, more transforms, drawing curves as SVG
  and reading them from SVG, and a tutorial with interactive Livebooks.

See the [changelog](changelog.html) for everything.

## Breaking changes

### 1. No more Nx

Results are plain 64-bit floats. The `:float_dtype` option is gone.

```elixir
# 0.2.x
Curves.define_bezier(:linear, float_dtype: 64)

# 1.0
Curves.define_bezier(:linear)
```

### 2. `Curves.Utils.Plotting` is replaced by `Curves.Svg`

```elixir
# 0.2.x
curve
|> Curves.Utils.Plotting.curve_to_scatterplot(count: 300)
|> Tucan.scatter("x", "y")

# 1.0
Curves.Svg.save!(curve, "curve.svg")
```

In Livebook: `curve |> Curves.Svg.render() |> Kino.Image.new(:svg)`.

### 3. Spline out-of-bounds errors include `u`

```elixir
# 0.2.x
{:error, :out_of_bounds} = Curves.solve(spline, 99.0)

# 1.0
{:error, {:out_of_bounds, 99.0}} = Curves.solve(spline, 99.0)
```

### 4. Curve fields are private

```elixir
# 0.2.x
spline.max_u

# 1.0
Curves.max_u(spline)
```

### 5. `Curves.Utils.Types` is now `Curves.Types`

```elixir
# 0.2.x
@spec move(Curves.Utils.Types.point_tuple()) :: Curves.Utils.Types.point_tuple()

# 1.0
@spec move(Curves.Types.point_tuple()) :: Curves.Types.point_tuple()
```

The tensor types `point/0`, `points/0` and `point_names/0` are gone: use `point_tuple/0` and `point_list/0`.

### 6. `:force_percent` changes

It works for every curve, whether passed to `define_*`, `solve` or `take`, or set in config. It measures
the curve after its transforms, so results stay between `0.0` and `1.0`, and a flat axis gives `0.5`.

```elixir
curve = Curves.define_bezier(:linear_horizontal)
Curves.solve!(curve, 0.5, force_percent: true)
# 0.2.x: {0.5, 1.0}
# 1.0:   {0.5, 0.5}
```

### 7. B-splines run in order

0.2.x solved B-spline segments backwards, so the curve jumped about as `u` grew. The shape is the same,
but `solve` gives different points for the same `u`.

### 8. Beziers need 2 to 4 points

```elixir
curve = Curves.define_bezier([{0, 0}, {1, 1}, {2, 0}, {3, 1}, {4, 0}])
Curves.solve(curve, 0.5)
# 0.2.x: raw tensors
# 1.0:   {:error, {:too_many_points, 5, 4}}
```

For longer paths, use a spline.

### 9. Hermite splines take tangents

Each point is `[knot, tangent]`, and the curve passes through every knot.

```elixir
# 0.2.x
Curves.define_hermite([{0, 0}, {2, 2}, {4, 0}])

# 1.0
Curves.define_hermite([[{0, 0}, {4, 0}], [{2, 2}, {0, 4}], [{4, 0}, {4, 0}]])
```

For automatic tangents, use `Curves.define_catmull_rom/2`.

### 10. Bezier spline points are SVG-style

Each point is a knot, then the control points of the curve *to the next knot*, like an SVG path:
`[knot]` is a line (`L`), `[knot, c]` a quadratic (`Q`), `[knot, c0, c1]` a cubic (`C`). The last point is
just `[knot]`.

```elixir
# 0.2.x: each knot with the handles it arrives from and leaves towards
Curves.define_bezier_spline([
  [{5, 10}, {10, 10}],
  [{10, 5}, {5, 5}, {15, 5}],
  [{30, 10}, {32, 5}]
])

# 1.0: the same curve
Curves.define_bezier_spline([
  [{5, 10}, {10, 10}, {5, 5}],
  [{10, 5}, {15, 5}, {32, 5}],
  [{30, 10}]
])
```

To convert old points:

```elixir
def to_svg_style(points) do
  points
  |> Enum.chunk_every(2, 1)
  |> Enum.map(fn
    [[knot | _] = point, next] -> [knot, leaving(point), arriving(next)]
    [[knot | _]] -> [knot]
  end)
end

defp leaving([knot]), do: knot
defp leaving([_knot, c]), do: c
defp leaving([_knot, _arrive, leave]), do: leave

defp arriving([knot]), do: knot
defp arriving([_knot, c]), do: c
defp arriving([_knot, arrive, _leave]), do: arrive
```

### 11. Scaling no longer moves a curve

Curves are scaled and rotated around their own `{0, 0}`, then moved to their position.

```elixir
curve =
  Curves.define_bezier([{0, 0}, {4, 0}])
  |> Curves.Transform.set_position({10, 10})
  |> Curves.Transform.set_scale(2)

Curves.solve!(curve, 0.0)
# 0.2.x: {20.0, 20.0}
# 1.0:   {10.0, 10.0}
```

Only curves that are both moved and scaled change.

### 12. `Predefined.get_coords/1` raises for an unknown name

```elixir
Curves.Bezier.Predefined.get_coords(:nope)
# 0.2.x: nil
# 1.0:   raises ArgumentError
```
