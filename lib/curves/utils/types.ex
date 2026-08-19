defmodule Curves.Utils.Types do
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

  @typedoc "@TODO WIP A keyword list of options."
  @type opts :: keyword()

  @typedoc "Provides a formal structure for the {2, n} Tensors that represent a series of n points with two dimension values (x and y)"
  @type point_names :: list( :dimension | :point )

  @typedoc "An Nx tensor representing a single point"
  @type point :: %Nx.Tensor{shape: {2, 1}, names: point_names(), type: {:f, pos_integer()}}

  @typedoc "An Nx tensor representing a series of points"
  @type points :: %Nx.Tensor{shape: {2, pos_integer()}, names: point_names(), type: {:f, pos_integer()}}
end
