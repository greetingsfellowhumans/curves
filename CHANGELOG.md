# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [0.2.2] - 2026-08-17

### Added

- `force_percent` opt

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
