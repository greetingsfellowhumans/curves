defmodule Curves.Utils.TensorTypes do
  @moduledoc ~s"""
  Typespecs for the `Nx` tensors used throughout Curves. There are no functions here.

  Every type is an `Nx.Tensor` with a fixed shape and named axes. The axis names matter:
  code reads values by name, e.g. `points[dimension: 0]` for every x.

  | type | shape | axis names | holds |
  | --- | --- | --- | --- |
  | `t:point/0` | `{2, 1}` | `[:dimension, :point]` | one `{x, y}` |
  | `t:flat_point/0` | `{2}` | `[:dimension]` | one `[x, y]`, with no `:point` axis |
  | `t:points/0` | `{2, n}` | `[:dimension, :point]` | n `{x, y}` points |
  | `t:cubic_segment/0` | `{2, 4}` | `[:dimension, :point]` | `[knot0, control_point0, control_point1, knot1]` |
  | `t:cubic_segments/0` | `{n, 2, 4}` | `[:segment, :dimension, :point]` | n segments |
  | `t:rotation_matrix/0` | `{2, 2}` | `[:dimension, :point]` | a 2D rotation |
  | `t:power_series/0` | `{4}` | unnamed | `[1, t, t², t³]` or its derivative |

  The `:dimension` axis always has size 2: index 0 is x and index 1 is y.
  """

  @typedoc "The float type of a tensor, e.g. `{:f, 32}`. Set with the `:float_dtype` option."
  @type float_type :: {:f, pos_integer()}

  @typedoc "Axis names for a point, a list of points, a single segment or a rotation matrix."
  @type point_names :: list(:dimension | :point)

  @typedoc "Axis names for a list of segments."
  @type segment_names :: list(:segment | :dimension | :point)

  @typedoc "A single `{x, y}` point, shape `{2, 1}`."
  @type point :: %Nx.Tensor{shape: {2, 1}, names: point_names(), type: float_type()}

  @typedoc """
  A single `[x, y]` with no `:point` axis, shape `{2}`.

  Indexing one point out of `t:points/0` (e.g. `points[point: 0]`) drops the `:point` axis and gives this.
  """
  @type flat_point :: %Nx.Tensor{shape: {2}, names: [:dimension], type: float_type()}

  @typedoc "A series of n `{x, y}` points, shape `{2, n}`."
  @type points :: %Nx.Tensor{
          shape: {2, pos_integer()},
          names: point_names(),
          type: float_type()
        }

  @typedoc "One cubic segment, `[knot0, control_point0, control_point1, knot1]`, shape `{2, 4}`."
  @type cubic_segment :: %Nx.Tensor{shape: {2, 4}, names: point_names(), type: float_type()}

  @typedoc "n cubic segments stacked along the `:segment` axis, shape `{n, 2, 4}`."
  @type cubic_segments :: %Nx.Tensor{
          shape: {pos_integer(), 2, 4},
          names: segment_names(),
          type: float_type()
        }

  @typedoc "A 2D rotation matrix, shape `{2, 2}`. See `Curves.Transform.set_rotation/2`."
  @type rotation_matrix :: %Nx.Tensor{shape: {2, 2}, names: point_names(), type: float_type()}

  @typedoc "A cubic power series `[1, t, t², t³]` (or one of its derivatives), shape `{4}`."
  @type power_series :: %Nx.Tensor{shape: {4}, names: [nil], type: float_type()}
end
