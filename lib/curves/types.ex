defmodule Curves.Types do
  @moduledoc ~s"""
  A collection of typespecs to be used in other modules. There are no meaningful functions to be found here.
  """

  @typedoc ~s"""
  The order of a curve is (the number of control points) - 1.
  Although a more accurate definition might be "the depth of recursion when interpolating".

  ```code
  Linear == 1
  Quadratic == 2
  Cubic == 3
  ```

  So for example, if you have a straight line (formed from only 2 points) and want to find a new point at 50%, you are interpolating exactly 1 time to do so.


  If you have a quadratic, with 3 points, you first interpolate between p0->p1 and p1->p2, thus creating two new dots. Then you recurse, creating a new line from those new dots, and interpolate again.


  Cubic curves would recursively interpolate once more.
  """
  @type order :: 1 | 2 | 3

  @typedoc "A single number, represented as either x or y in 2D space"
  @type coord :: number()

  @typedoc ~s"""
  An {x, y} pair representing a coordinate in 2D space
  """
  @type point_tuple :: {x :: coord(), y :: coord()}

  @typedoc "A list of {x, y} number coordinates"
  @type point_list :: list(point_tuple())

  @typedoc "A keyword list of options. See the Options section of `Curves` for the keys."
  @type opts :: keyword()

  @typedoc ~s"""
  Float between 0.0 and 1.0, representing a percentage of progress from the first to last point.
  """
  @type t :: float()

  @typedoc ~s"""
  All 'define_*' functions can receive the following options:

  | `key` | `default` | `description` |
  | --- | ---     | --- |
  | `:origin` | `{0, 0}` | Provides an offset. every point in the curve will automatically be increased by this {x, y} coordinate |

  """
  @type define_opts :: [origin: point_tuple()]

  @typedoc ~s"""
  Either a Bezier or Spline struct
  """
  @type curve_struct() :: Curves.Bezier.Curve.t() | Curves.Spline.Curve.t()

  # A Bezier or Spline struct seen as a plain map. Internal helpers (Curves.Transform,
  # Curves.Utils.Percent) use this instead of curve_struct(), because the structs are opaque:
  # only Curves.Bezier.Curve and Curves.Spline.Curve may read their fields, so they are the
  # only modules that call these helpers.
  @typedoc false
  @type curve_data() :: %{optional(atom()) => term()}
end
