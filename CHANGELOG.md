# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-21

The first stable release. From here on, breaking changes wait for 2.0. Since 1.0.0-rc.2 there are bug fixes and clearer docs, listed below, and no breaking changes.

Coming from 0.2.x? The changes are listed under [1.0.0-rc.2](#1-0-0-rc-2-2026-10-11) and [1.0.0-rc.1](#1-0-0-rc-1-2026-10-10) below, and the [upgrade guide](upgrading.html) shows how to update for each breaking change. In short:

- **Faster, with no dependencies**: Nx is gone, everything runs on plain 64-bit floats, and solving a point is 40–130× faster.
- **More correct**: Hermite splines pass through their knots, B-splines run in order, `:force_percent` works everywhere, and bad input raises a clear `ArgumentError`.
- **More curves**: polylines, nine kinds of spline, and exact elliptical arcs, ellipses and circles.
- **More transforms**: separate x and y scales, flips, `reverse/1`, and turning around any point with `around:`.
- **SVG in and out**: `Curves.Svg` draws any curve or drawing, and `Curves.from_svg/2` reads an SVG's shapes as curves.
- **New docs**: a four-chapter tutorial with interactive Livebooks, and a guide to choosing a curve.

### Added

- `Curves.Drawing.Group` has a `:transform` field: every SVG `transform` that applied to the group, like a shape's `:transform`. `Curves.Svg` draws the group with it.
- `Curves.Drawing` has a `:read_with_flip_y` field: whether `Curves.from_svg/2` was given `flip_y: true`.

### Changed

- The [upgrade guide](upgrading.html) is much shorter: why to upgrade, then one before-and-after example for each breaking change.
- The introduction's first example solves the curve at `t = 0.5`, matching its picture.
- Catmull-Rom splines are built in time proportional to the number of knots, not its square: 8,000 knots take about a fifth of the time.
- `Curves.Svg` writes a closed shape's path data without the extra line back to its start before `Z`, so markers aren't drawn twice at the start.
- `Curves.Svg` writes numbers in a transform that are within rounding of a whole number as that number, e.g. `0.0` instead of `6.123233995736766e-17`.
- Clearer docs:
  - The options table in `Curves` says that `solve` and `take` ignore `:origin`, and that unknown options are ignored.
  - `Curves.Bezier.Predefined` says which names share a curve (`:ease` is `:ease_in`, for example), and gives CSS's own points; the guide to choosing a curve no longer says the presets are CSS's.
  - `Curves.Transform` says that `around: :center` on a drawing counts only its shapes (text can't be measured), that the move made by `around:` stays, and what `inc_scale/3` does to a flipped curve.
  - `Curves.Svg` says that CSS picking shapes by element (like `rect { ... }`) no longer matches them once drawn, since every shape is a `<path>`.
  - `Curves.from_svg/2` says that an empty `<g/>` is left out, and `Curves.Drawing.by_id/1` says when it raises.

### Fixed

- A drawing drawn with `Curves.Svg`:
  - A group's `clip-path`, `mask` or `filter` lines up with its shapes again: the group is drawn with its own `transform`, as in the SVG, not with that transform moved onto each shape inside it.
  - A `<use>` of a shape inside a transformed group no longer gets the group's transform as well.
  - An SVG with a `width` and `height` in pixels but no `viewBox` shows `0..width` by `0..height`, as SVG does, instead of being zoomed in to its curves (flipped when read with `flip_y: true`).
  - An SVG with a `viewBox` but no `width` or `height` is drawn with none, so it fills the space it is shown in, as before, instead of being 1 pixel per unit.
  - The view box fitted to a drawing without one is exact: it no longer cuts off the tips of arcs, like a rounded rectangle's corners.
  - Flat content, like a single horizontal line, gets a view box 1 unit across, not `1.0e-9`.
  - Line breaks and tabs in an attribute are written as `&#10;` and `&#9;`, so they read back the same.
- Reading SVGs:
  - Path data may have a comma between repeated sets of arguments, as SVG allows, e.g. `M0,0,10,10` or `L1 2,3 4`.
  - A character reference to a character XML doesn't allow, like `&#0;`, is kept as written, so a drawing drawn again is still valid XML.
- `Curves.Drawing.shapes/1` resets a shape's own move, scale and rotation even when they cancel out its groups', so a shape put back into a drawing isn't moved twice.
- Solving a spline or polyline at a `u` up to `0.001` past `max_u` (a rounding error, like adding `0.1` thirty times) gives its end, instead of an out-of-bounds error. It already allowed the same below `0`.
- Clear `ArgumentError`s, as for Bezier curves and polylines:
  - every spline's `define_*` with a bad `:origin` (was a `MatchError`), or with points that aren't a list, like a single `{x, y}` (was a `Protocol.UndefinedError`);
  - `Curves.max_u/1` with something that isn't a curve (was a `FunctionClauseError`);
  - `Curves.Drawing.update_shapes/2` with a function that returns `:delete`.

## [1.0.0-rc.2] - 2026-10-11

The second release candidate. It has three breaking changes, listed under Changed; sections 10 to 12 of the [upgrade guide](upgrading.html) show how to update.

### Added

#### New kinds of curve

- `Curves.define_polyline/2` makes a `Curves.Polyline.Curve`: knots joined by straight lines, like SVG's `<polyline>`. It is solved with `u` like a spline (each line adds one to `u`), at a steady speed along each line, and works with `take`, the transforms, `:force_percent` and `Curves.Svg`.
- Five new kinds of spline. Like Catmull-Rom, you only give each one the knots, and it passes through every one of them. Each has its own module under `Curves.Spline.Type`, and works with `take`, the transforms, `:force_percent` and `Curves.Svg`:
  - `Curves.define_cardinal/2`: Catmull-Rom with a `:tension` option that sets how tightly it bends at each knot (d3's `curveCardinal`).
  - `Curves.define_centripetal_catmull_rom/2`: Catmull-Rom that takes the distances between knots into account, so it never makes loops or cusps. Its `:alpha` option (default `0.5`) also gives plain (`0.0`) and chordal (`1.0`) Catmull-Rom.
  - `Curves.define_kochanek_bartels/2`: a TCB spline, Catmull-Rom with `:tension`, `:continuity` and `:bias` dials, as used for keyframes in animation tools.
  - `Curves.define_monotone/2`: a monotone cubic spline (Fritsch–Carlson) for chart data. It never overshoots: between two knots it only goes up, down or stays flat. Each knot's `x` must always increase (or always decrease).
  - `Curves.define_natural_cubic/2`: the smoothest curve through every knot, with a continuous bend everywhere.
- Exact elliptical arcs, which aren't made of Bezier curves:
  - `Curves.define_bezier_spline/2` takes `[knot, {:arc, rx, ry, rotation, large_arc, sweep}]`, an arc to the next knot exactly like SVG's `A` command, with SVG's rules for radii that are too small, zero or negative.
  - `Curves.define_ellipse/3` and `Curves.define_circle/3` make an ellipse or circle, or an arc of one with the `:from` and `:to` options (in degrees), like a canvas's `arc()` and `ellipse()`. It is one segment, so `u` goes from `0.0` to `1.0`, and a whole one ends exactly where it started.
  - Arcs work with every transform (even different x and y scales), `reverse/1`, `:force_percent` and `Curves.Svg`. They start and end exactly on their knots. The curve stores extra points that the arc stays inside, which `Curves.Svg` draws as dots.

#### Transforms

- More transforms in `Curves.Transform`:
  - `set_scale/3` and `inc_scale/3` take an `{x, y}` pair to scale the two directions separately, e.g. `set_scale(curve, {2, 0.5})`.
  - `flip_x/2` and `flip_y/2` mirror a curve.
  - An `around:` option on the scale, flip and rotation functions turns the curve around `:center` (the middle of its points) or any `{x, y}` point in its own coordinates, which then stays where it is.
  - `reverse/1` gives the same curve travelled the other way.

#### Reading and drawing SVGs

- `Curves.from_svg/2` reads an SVG into a `Curves.Drawing`:
  - Its shapes (`<path>`, `<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polyline>` and `<polygon>`) become curves, with a `Curves.Drawing.Subpath` per continuous piece, holding a curve and whether it is closed. Every path command works, with exact arcs.
  - Every `transform` (on shapes and groups, even `skewX`, `skewY` and `matrix`) is applied to the curves exactly.
  - It keeps the SVG's structure (`Curves.Drawing.Group`), each shape's styles and transform, and everything that isn't curves (text, `<defs>`, `<style>`, ...) as markup (`Curves.Drawing.Raw`). `Curves.Drawing.shapes/1` and `curves/1` list everything in it.
  - Anything that can't be read as curves (text, images, `<use>`, sizes in `%` or `em`, bad path data, ...) is listed in the drawing's `:skipped` field with the reason.
  - `flip_y: true` turns SVG's downward y around.
  - It has no XML library and never creates atoms from its input. `<script>`, `<foreignObject>`, animations of links and event handlers, event attributes and `javascript:` links are never kept, and kept markup is always well formed.
  - Every `Curves.Transform` function also takes a whole drawing, or a group, shape or subpath in it, and changes it as a whole, text included; `around: :center` is its middle. The change is kept on the drawing, group or shape (`:origin`, `:scale`, `:rotation`), like a curve's.
  - `Curves.Drawing.get/2`, `fetch/2`, `put/3`, `update/3` and `delete/2` find and change a part by its `id`; `get_in/2` and `update_in/3` follow a path of ids; `by_id/1` does the same for `Kernel.get_in/2`, `update_in/3` and `pop_in/2`; `update_shapes/2` and `update_curves/2` change every shape or curve.
  - Each entry in `:skipped` says what was kept of it: `kept: :as_markup`, `:partly` or `:no`. The reason `:not_curves` (text, images, ...) is told apart from `:unsafe` (`<script>`, `<foreignObject>`).
- `Curves.from_svg_path/2` reads just the path data of one `<path>`.
- `Curves.Svg.render/2` and `save!/3` draw a `Curves.Drawing` as designed: in its own size and view box, with its groups, colours, text and gradients, so it looks like the SVG it was read from. `mode: :inspect` draws it like a curve instead.
- `Curves.Svg.path_data/1` writes any curve as exact SVG path data: `C` commands for each spline segment (every kind of spline), `A` for arcs (even skewed ones), and `L` for straight lines.
- `Curves.Svg` has a `:view` option, `{{x1, y1}, {x2, y2}}`, that draws a fixed area instead of fitting the picture to the curve, so several pictures or animation frames share the same scale.
- `Curves.Svg` has a `:markers` option that highlights extra `{x, y}` points, e.g. `markers: [Curves.solve!(curve, 0.5)]` to show where `t = 0.5` lands. `:marker_color` and `:marker_radius` style them.
- `Curves.Svg` has a `:show_axes` option that draws a grid with the x and y values along the bottom and left edges, like a ruler, so you can see a curve's real size and position. The x = 0 and y = 0 lines are darker. `:axis_color` sets its colour. It is on by default; `show_axes: false` gives the old look.

#### Docs

- A new tutorial for new users, in four chapters: your first curve, Bezier curves, splines, and transforms and drawing. The hexdocs version is full of pictures drawn with `Curves.Svg`, and its simplified first page is now the docs' landing page. Each chapter is also an interactive Livebook with sliders, animations and an easing race. They replace the two old livebooks.
- A new guide, [Choosing a curve](choosing_a_curve.html), compares every kind of curve, with real-world examples of where each is used.
- `Curves.Bezier.Predefined`'s docs show a picture of every predefined curve.

### Changed

- **Breaking:** Bezier spline points are SVG-style. Each point is a knot, then the control points of the curve *to the next knot*: `[knot]` is a straight line (SVG `L`), `[knot, c]` a quadratic curve (`Q`) and `[knot, c0, c1]` a cubic curve (`C`). They used to be the two handles of the knot itself (the control point the curve arrives from, and the one it leaves towards). The last point only ends the curve, so control points there (including on a single knot) raise an `ArgumentError`. Old points without them still work, but draw a different curve. The [upgrade guide](upgrading.html) has a function that converts old points to new ones exactly.
- **Breaking:** Transforms apply in the usual scale, rotate, move order: a curve is scaled and rotated around its own `{0, 0}`, then moved to its position. The position used to be scaled too, so scaling a moved curve also moved it (e.g. from `{10, 10}` to `{20, 20}` with `set_scale(2)`), and a rotation then turned it around a point that was no longer on the curve. Only curves that are both moved and scaled give different results. See the [upgrade guide](upgrading.html).
- **Breaking:** `Curves.Bezier.Predefined.get_coords/1` raises an `ArgumentError` for a name that isn't a predefined curve, like `details/1` does. It used to return `nil`.
- `Curves.Svg` draws the dashed lines of beziers and bezier splines from each control point to the knot it pulls on, instead of one line through every point. A straight line has none.
- `Curves.Svg` images now include the axes grid by default (see `:show_axes` above).
- Passing something that isn't a curve to `Curves.solve/3`, `solve!/3`, `take/3`, `take!/3`, the `Curves.Transform` functions, or `Curves.Svg.render/2` and `save!/3` now raises an `ArgumentError` such as `expected a Curves.Bezier.Curve, Curves.Spline.Curve or Curves.Polyline.Curve, got: :nope`. It used to raise a `CaseClauseError`, `FunctionClauseError`, `KeyError` or `UndefinedFunctionError`, depending on the function and the input.
- Other invalid input now raises an `ArgumentError` that says what was expected, instead of an error from deep inside the library:
  - an unknown predefined curve name (`define_bezier(:nope)`, `Predefined.details/1`, `Predefined.get_coords/1`) or `Predefined.list/1` order.
  - `define_bezier/2` given something that isn't a list or a name, e.g. a single `{x, y}`.
  - any point, `:origin`, or `Curves.Transform` position that isn't an `{x, y}` tuple of numbers, in every `define_*` function.
  - a `t`/`u` that isn't a number in `solve/3` and `solve!/3`.
  - a `Curves.Transform` amount (`inc_x/2`, `set_scale/2`, `set_rotation/2`, ...) that isn't a number.
  - an unknown spline type (it was a `RuntimeError`).
- `Curves.Svg`'s `show_points`, `show_polygon` and `show_axes` treat `nil` like `false`. `show_points: nil` used to crash, and `show_polygon: nil` drew the polygon.

### Fixed

- Dialyzer no longer warns about breaking the opaqueness of `Curves.Bezier.Curve.t()` and `Curves.Spline.Curve.t()` inside the library. Code outside the two curve modules no longer reads or matches their fields.
- `Curves.Svg` no longer misplaces its grid when a curve's points differ only by rounding (e.g. a rotated straight line far from `{0, 0}`). Such tiny differences were blown up to fill the picture, which lost all precision; they now count as flat.
- Bezier `take/3` and `take!/3` end exactly at the end of the curve. For some `n` (e.g. 49) the last sample used to be at `t = 0.9999999999999999`, so it was very slightly short of the last point.

## [1.0.0-rc.1] - 2026-10-10

The first release candidate for 1.0. Version 0.3.0 was never released; its changes ship here.
Coming from 0.2.x? See the [upgrade guide](upgrading.html).

### Added

- `Curves.max_u/1` returns the highest `t`/`u` a curve accepts: `1.0` for beziers, the number of segments for splines.
- `Curves.Svg` draws any Bezier or Spline curve as an SVG image, with no extra dependencies. `render/2` returns the SVG as a string and `save!/3` writes it to a file. Options control the number of samples (default 100), the size, colours, title, and whether the curve's points and the dashed line joining them are drawn.

### Changed

- **Breaking:** `define_hermite/2` now takes each point as `[knot, tangent]` (both `{x, y}`) and builds a true cubic Hermite spline: it passes exactly through every knot and leaves each one along its tangent. It used to take bare knots and compute its own slopes. For automatic tangents, use `define_catmull_rom/2`.
- **Breaking:** The curve structs (`Curves.Bezier.Curve`, `Curves.Spline.Curve`) are now opaque: their fields are internal and may change in any 1.x release. Use `Curves.max_u/1` instead of reading `curve.max_u`.
- **Breaking:** Splines now read the app-wide `:force_percent` setting on every `solve`/`take`, like beziers do. Previously they read it only when defined or transformed.
- **Breaking:** With `:force_percent`, an axis where every point has the same value (a flat curve) now returns `0.5` instead of that raw value, so results are always numbers in `0.0..1.0`.
- **Breaking:** Curves no longer uses Nx, and has no runtime dependencies. Points are plain `{x, y}` float tuples and results are 64-bit floats (0.2.x used 16-bit by default), so values differ slightly in their last digits. The `:float_dtype` option is gone; passing it has no effect.
- **Breaking:** Removed `Curves.Utils.Plotting`, which the 0.2.x livebooks used with VegaLite and Tucan. Use `Curves.Svg.render/2` instead (in Livebook: `Kino.Image.new(svg, :svg)`).
- **Breaking:** `Curves.Utils.Types` is now `Curves.Types`. Its Nx tensor types (`point/0`, `points/0` and `point_names/0`) are gone along with Nx; use `Curves.Types.point_tuple/0` and `point_list/0`.
- **Breaking:** Spline out-of-bounds errors now include the offending `u`, matching the bezier error shape. `{:error, :out_of_bounds}` is now `{:error, {:out_of_bounds, u}}`.
- Everything is much faster now that it runs on plain floats instead of Nx (measured against 0.2.x's code on the same machine): solving a point takes 0.15–0.26 µs instead of 9–34 µs (40–130×), `take!/3` of 100 points takes 14–17 µs instead of 2.8–3.5 ms (about 200×), defining a curve is 6–9× faster (Hermite: 9 µs instead of 778 µs), and `Curves.Svg.render/2` of a spline takes about 65 µs.
- `take/3` and `take!/3` raise an `ArgumentError` when `n` isn't a positive integer. `n = 0` used to crash with an `ArithmeticError`, and a negative `n` returned a misleading `{:error, {:out_of_bounds, _}}`.
- `define_b_spline/2` with fewer than 4 points, and `define_catmull_rom/2` or `define_bezier_spline/2` with an empty list, raise an `ArgumentError` saying how many points are needed, instead of an `Enum.EmptyError` or `FunctionClauseError` from deep inside the library.
- `define_bezier_spline/2` raises an `ArgumentError` explaining the expected point format when a point isn't a list of 1 to 3 `{x, y}` tuples (e.g. a plain `{x, y}`), instead of a `FunctionClauseError` from deep inside the library.
- Bezier curves with fewer than 2 points can now be defined and transformed. Solving them returns `{:error, {:too_few_points, n, 2}}` instead of crashing in `define_bezier/2`.

### Fixed

- `Curves.Svg.render/2` no longer crashes (`0.0 * :infinity`) for a curve whose points are all the same; it draws it at the centre of the image.
- Hermite splines missed their own knots (e.g. `{10.0017, 5.0033}` instead of `{10, 5}`), moved by the wrong amount when transformed, and could produce huge values near vertical slopes. The slope's axes were swapped, vertical slopes became `{1_000_000, 1}`, and Bezier-style control points were fed into the Hermite formula. Replaced by a correct cubic Hermite spline (see Changed).
- The exceptions (`OutOfBoundT`, `OutOfBoundU`, `TooFewPoints`, `TooManyPoints`) now fill in their fields (`t`, `u`, `max`, `n`, `min`) instead of leaving them `nil`, and are documented.
- Spline `solve/3` and `solve!/3` accept integer `u` values instead of raising `FunctionClauseError`.
- Spline `take!/3` raises `Curves.Exceptions.OutOfBoundU` instead of a `MatchError`.
- Spline `take/3` no longer fails when float rounding pushes the final sample past the last segment.
- Splines solved at a `u` within 0.0001 of the start now return the right point instead of the start point. A small negative `u` (allowed down to -0.001) now extends slightly before the start, instead of being mirrored to just after it.
- `:force_percent` passed to `solve/3` or `take/3` is now honoured for splines.
- `:force_percent` passed to `define_bezier/2`, or set in application config, is now honoured for bezier curves.
- `:force_percent` now rescales using the curve's position after moves, scaling, rotation and the `:origin` option, so transformed curves return values between `0.0` and `1.0`. Previously it used the points as defined, so transformed curves could return values far outside that range. Untransformed curves are unchanged. Rotating a flat curve can make that axis return values from `0.0` to `1.0`, because rotation adds tiny rounding errors.
- B-spline segments were solved in reverse order, so as `u` increased the curve jumped between segments instead of running smoothly from start to end. They now run in order. `solve/3` and `take/3` return different points for the same `u` on B-splines, but the overall shape is unchanged.
- Bezier curves with more than 4 points now return `{:error, {:too_many_points, n, 4}}` (or raise `Curves.Exceptions.TooManyPoints`) instead of returning raw tensors.

## [0.2.7] - 2026-09-21

### Changed

- Simplified the Livebook plotting. Removed labels and dots. Using Tucan's builtin functions for scaling.

## [0.2.6] - 2026-09-21

### Added

- Transform functions (position, rotate, scale)

## [0.2.5] - 2026-09-19

### Added

- Splines! 🥳🥳🥳

This is the first release with splines. There should be no breaking changes, so it is still a patch version.
Four Spline types have been defined: Hermite, CatmullRom, BezierSpline, and BSpline. All are using uniform cubic implementations.

### Changed

- Documentation has been overhauled quite a lot. Better typespecs. Options are finally documented.

## [0.2.4] - 2026-08-29

### Fixed

- Predefined curve linear uses Y=1.0 instead of Y=0.0, du

## [0.2.3] - 2026-08-18

### Added

- Lots of documentation and typespecs
- more helper functions in `Curves.Utils.Predefined`

### Changed

Exposed some modules to documentation that were previously set to `@moduledoc false`.

## [0.2.2] - 2026-08-17

### Changed

- Support forcing curves to use percents

## [0.2.1] - 2026-08-17

### Added

- `Curves.take/3` and `Curves.take!/3`

## [0.2.0] - 2026-08-16

A lot of preparatory work before implementing splines.
This release tightens up and polishes the API for bezier curves.

### BREAKING CHANGES

`Curves.define_curve/2` renamed `Curves.define_bezier`.
originally I was hoping the API could intelligently switch between bezier and spline, but upon closer investigation, it won't work.
For one thing, a curve with 4 points would be ambiguous. Which is it, bezier or spline?

### Added

- Predefined bezier curves
- `Curves.Utils.Plotting` which simplifies and beautifies the livebook experience. Maybe a user can also get some other use out of it.
- More docs, tests, typespecs.

## [0.1.0] - 2026-08-09

### Added

The initial release.
