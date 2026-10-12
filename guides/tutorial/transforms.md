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

## Stretch, flip and turn around a point

Give `set_scale/3` an `{x, y}` pair to scale the two directions separately, and use `flip_x/2` or
`flip_y/2` to mirror a curve:

| | |
| --- | --- |
| ![Stretched](images/transform_stretched.svg) | ![Flipped](images/transform_flipped.svg) |
| `Transform.set_scale(shape, {2, 0.5})` | `Transform.flip_y(shape, around: :center)` |

By default, everything turns around the curve's own `{0, 0}` (here, its first point). Pass `around:` to
turn around a different point, which then stays exactly where it is: `:center` is the middle of the curve's
points, or give any `{x, y}` in the curve's own coordinates. The purple dot is the point it turned around:

| | | |
| --- | --- | --- |
| ![The original](images/transform_pivot_none.svg) | ![Around {0, 0}](images/transform_pivot_position.svg) | ![Around the center](images/transform_pivot_center.svg) |
| `shape` | `Transform.set_rotation(shape, 90)` | `Transform.set_rotation(shape, 90, around: :center)` |

`around:` works with `set_scale/3`, `inc_scale/3`, `flip_x/2`, `flip_y/2`, `set_rotation/3` and `inc_rotation/3`.

## Going backwards

`Transform.reverse/1` gives you the same curve travelled the other way, so `t = 0.0` is its old end.
Its shape doesn't change. It's handy to play an easing backwards, or to follow a path in reverse:

```elixir
Curves.solve!(shape, 0.0)
#=> {0.0, 0.0}
shape |> Transform.reverse() |> Curves.solve!(0.0)
#=> {4.0, 0.0}
```

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

## Reading curves from an SVG

Going the other way, `Curves.from_svg/2` reads an SVG (a logo, an icon, a drawing from Inkscape or
Figma) into a `Curves.Drawing`. Its shapes become curves you can solve, take, transform and draw like
any other, and it keeps everything else (groups, colours, text, gradients) so it can be drawn again
just as it was.

```elixir
house = """
<svg width="300" height="300" viewBox="0 0 100 100">
  <rect x="0" y="0" width="100" height="100" fill="#e7f5ff"/>
  <polygon points="10,50 50,15 90,50" fill="#e03131"/>
  <rect x="18" y="50" width="64" height="40" fill="#ffe8cc" stroke="#862e9c"/>
  <rect x="42" y="65" width="16" height="25" rx="3" fill="#862e9c"/>
  <circle cx="50" cy="35" r="6" fill="#fff" stroke="#862e9c" stroke-width="2"/>
  <path d="M 70 30 V 18 h 8 v 22" fill="#495057"/>
  <text x="50" y="98" font-size="6" text-anchor="middle">Home</text>
</svg>
"""

drawing = Curves.from_svg(house)

for shape <- Curves.Drawing.shapes(drawing), subpath <- shape.subpaths do
  Curves.solve!(subpath.curve, 0.5)
end

# Draw it again, as designed
Curves.Svg.save!(drawing, "house.svg")
```

![A drawing read from an SVG and drawn again](images/svg_import_drawing.svg)

Every shape works: paths (with exact arcs), rectangles, circles, ellipses, lines, polylines and polygons.
Every `transform` is already applied to the curves, even skews. Anything that isn't made of curves, like
the text, is listed in `drawing.skipped`, and kept so it is drawn again.

The `Curves.Transform` functions work on a whole drawing too, and on any part of it you find by its
`id`, so you can turn a drawing into an animation:

```elixir
drawing
|> Curves.Transform.set_scale(0.5, around: :center)
|> Curves.Drawing.update("chimney", &Curves.Transform.inc_y(&1, -5))
```

Text and everything else in the drawing move along with the shapes.

To see the curves themselves, draw it like a curve with `mode: :inspect`: in the curve colour, with
their dots and dashed lines. SVG's y goes *down* the screen, but Curves' y goes up, like a graph, so
read it with `flip_y: true` to have it the right way up:

```elixir
house
|> Curves.from_svg(flip_y: true)
|> Curves.Svg.save!("house_curves.svg", mode: :inspect)
```

![The same drawing's curves](images/svg_import_curves.svg)

For just the path data of one `<path>`, use `Curves.from_svg_path/2`. It gives one subpath for each
separate piece of the path:

```elixir
[heart] =
  Curves.from_svg_path(
    "M 10,30 A 20,20 0,0,1 50,30 A 20,20 0,0,1 90,30 Q 90,60 50,90 Q 10,60 10,30 z",
    flip_y: true
  )

Curves.Svg.render(heart.curve)
```

![A heart read from SVG path data](images/svg_import_heart.svg)

And to write a curve into your own SVG, `Curves.Svg.path_data/1` gives it as exact path data:

```elixir
Curves.Svg.path_data(Curves.define_circle({0, 0}, 1, to: 90))
#=> "M1.0,0.0 A1.0 1.0 0.0 0 1 6.123233995736766e-17,1.0"
```

## That's the tour!

You now know everything you need: curves and `t`, control points, splines and `u`, transforms,
drawing, and reading SVGs. The `Curves` module has the full API, and the interactive Livebooks are a great place to keep
experimenting.
