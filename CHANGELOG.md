# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Solving linear (2-point) and quadratic (3-point) bezier curves is about 2.4× faster and uses about a third of the memory. Results are unchanged.
- Defining curves is about 2–3× faster for beziers, B-splines, bezier splines and Catmull-Rom splines, and about 20% faster for Hermite splines. A rotation of `0.0`, which every new curve starts with, is now skipped instead of computed. Results are unchanged. Moving or scaling an unrotated curve gets the same speedup.
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
