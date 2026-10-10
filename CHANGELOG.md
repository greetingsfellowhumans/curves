# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-10-09

### Changed

- **Breaking:** The default `:float_dtype` is now `32` (was `16`). Results are more precise, so values will differ slightly from previous versions. Pass `float_dtype: 16` to restore the old behaviour.
- **Breaking:** Spline out-of-bounds errors now include the offending `u`, matching the bezier error shape. `{:error, :out_of_bounds}` is now `{:error, {:out_of_bounds, u}}`.
- Solving linear (2-point) and quadratic (3-point) bezier curves is about 2.4× faster and uses about a third of the memory. Results are unchanged.
- Bezier curves with fewer than 2 points can now be defined and transformed. Solving them returns `{:error, {:too_few_points, n, 2}}` instead of crashing in `define_bezier/2`.

### Fixed

- Spline `solve/3` and `solve!/3` accept integer `u` values instead of raising `FunctionClauseError`.
- Spline `take!/3` raises `Curves.Exceptions.OutOfBoundU` instead of a `MatchError`.
- Spline `take/3` no longer fails when float rounding pushes the final sample past the last segment.
- `:force_percent` passed to `solve/3` or `take/3` is now honoured for splines.
- `:force_percent` passed to `define_bezier/2`, or set in application config, is now honoured for bezier curves.
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
