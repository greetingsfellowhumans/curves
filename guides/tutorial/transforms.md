# 4. Transforms and drawing

> Prefer to play? This chapter is also an [interactive Livebook](../livebooks/04_transforms.livemd) with sliders for
> position, scale and rotation.

## Moving, scaling and rotating

`Curves.Transform` changes where a curve is, how big it is, and which way it faces, without you having to
change its points. Every curve below starts from the same shape:

```elixir
alias Curves.Transform

shape = Curves.define_bezier([{0, 0}, {1, 3}, {3, 3}, {4, 0}])
```

| | |
| --- | --- |
| ![The original](images/transform_original.svg) | ![Moved](images/transform_moved.svg) |
| `shape` | `Transform.set_position(shape, {5, 2})` |
| ![Scaled](images/transform_scaled.svg) | ![Rotated](images/transform_rotated.svg) |
| `Transform.set_scale(shape, 2)` | `Transform.set_rotation(shape, 90)` |

Look at the numbers on the grid: the drawings are always scaled to fit the picture, so the axes are what
show the curve's real size and position.

- **Position** moves the curve so that its own `{0, 0}` sits at the new spot.
- **Scale** multiplies the size: `2` doubles it, `0.5` halves it, and a negative scale flips it.
- **Rotation** turns it counter-clockwise, in degrees.

## Doing all three

Transforms always happen in the same order, whatever order you call them in: the curve is **scaled**,
then **rotated**, then **moved** to its position. So scaling and rotating never move a curve away from
where you put it:

```elixir
shape
|> Transform.set_position({5, 2})
|> Transform.set_scale(2)
|> Transform.set_rotation(45)
|> Curves.solve!(0.0)
#=> {5.0, 2.0}
```

![Moved, scaled and rotated](images/transform_all.svg)

## `set_` or `inc_`?

Each transform comes in two flavours:

- `set_position/2`, `set_scale/2` and `set_rotation/2` replace the current value.
- `inc_position/2`, `inc_x/2`, `inc_y/2`, `inc_scale/2` and `inc_rotation/2` add to it.

```elixir
shape
|> Transform.set_rotation(30)
|> Transform.inc_rotation(15)    # now rotated by 45 degrees
```

## Results between 0 and 1: `:force_percent`

Sometimes you don't care about the real coordinates, only about *where along the shape* a point is,
for example to drive an animation. The `:force_percent` option rescales every result so that the shape's
lowest point is `0.0` and its highest is `1.0`, on both axes:

```elixir
big = Transform.set_scale(shape, 3)
Curves.solve!(big, 0.5)
#=> {6.0, 6.75}
Curves.solve!(big, 0.5, force_percent: true)
#=> {0.5, 0.75}
```

![The same curve with force_percent](images/transform_percent.svg)

The "lowest and highest points" are those of the curve's own points (its knots and control points), so a
curve that bends less far than its control points, like this one, doesn't quite reach `1.0`.
You can also turn it on for your whole app with `config :curves, force_percent: true`.

## Drawing curves

`Curves.Svg.render/2` returns an SVG image as a string, and `Curves.Svg.save!/3` writes it to a file.
Its options let you change almost everything:

```elixir
Curves.Svg.save!(curve, "styled.svg",
  title: "Your colours",
  curve_color: "#e64980",
  curve_width: 6,
  point_color: "#5c940d",
  polygon_color: "#fab005",
  background: "#fff9db",
  show_axes: false
)
```

![A curve with custom colours](images/svg_styled.svg)

To highlight points, such as the result of `solve`, pass them as `:markers`:

```elixir
Curves.Svg.render(curve, markers: [Curves.solve!(curve, 0.5)])
```

See `Curves.Svg` for every option. In [Livebook](https://livebook.dev), show an image with
`Kino.Image.new(svg, :svg)`.

## That's the tour!

You now know everything you need: curves and `t`, control points, splines and `u`, transforms, and
drawing. The `Curves` module has the full API, and the interactive Livebooks are a great place to keep
experimenting.
