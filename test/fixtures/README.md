# Test fixtures

## reference_results.etf

Known-good results for about 220 curves: every predefined bezier, custom beziers and every spline type,
each with and without moves, scaling and rotation. For each curve it holds `solve/3` at a range of
`t`/`u` values (with and without `:force_percent`), `take/3`, and `Curves.Svg.render/2`.
`test/curves/reference_results_test.exs` checks the library still gives the same results,
within a small tolerance.

The cases and the recording code live in `test/support/reference_results.ex`.

### Regenerating

Only regenerate when a change in results is intended (and noted in the CHANGELOG):

```sh
MIX_ENV=test mix run -e 'Curves.Support.ReferenceResults.write!()'
```

Check the diff in test results before committing the new file.
