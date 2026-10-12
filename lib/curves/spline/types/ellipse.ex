defmodule Curves.Spline.Type.Ellipse do
  @moduledoc ~s"""
  An ellipse or circle, or an arc of one: made with `Curves.define_ellipse/3` or
  `Curves.define_circle/3`.

  It is one segment, so `u` goes from `0.0` to `1.0`, like `t` on a Bezier curve. By default it goes
  once all the way round, starting at the right-hand end of its x axis (`center + {rx, 0}`), the
  same place an SVG `<ellipse>` or `<circle>` starts. The `:from` and `:to` options (in degrees)
  give an arc of it instead, like a canvas's `arc()` and `ellipse()`.

  ```elixir
  curve = Curves.define_ellipse({0, 0}, {4, 2}, rotation: 30)

  # Find any point along the ellipse (u goes from 0.0 to 1.0)...
  Curves.solve!(curve, 0.25)

  # ...or draw it as an SVG image
  Curves.Svg.save!(curve, "ellipse.svg")
  ```

  ![An ellipse, tilted 30 degrees](images/ellipse.svg)

  ## Angles and direction

  Angles are in degrees, measured from the ellipse's own x axis. When `:to` is bigger than `:from`
  the angle goes up, which is anticlockwise in Curves' pictures (where y goes up) and clockwise on an
  SVG screen (where y goes down). When `:to` is smaller, it goes the other way. `u` moves through
  the angle at a steady rate: a steady speed on a circle, but on an ellipse it goes faster round
  the long sides.

  ## Stored points

  The arc is cut into pieces of at most a quarter turn, and the curve stores each piece's ends and
  the point where the tangents at those ends meet. The arc always stays inside these points, even
  after moving, scaling or rotating it, so `:force_percent` stays within `0.0..1.0` and
  `Curves.Svg` draws them as its dots, with dashed lines like a quadratic Bezier curve's. For a
  whole ellipse they are the corners of the box around it and the ends of its axes, so
  `around: :center` (see `Curves.Transform`) is exactly its centre.
  """
  use Curves.Spline.Type,
    override_segment_parsing: true

  alias Curves.Types, as: T
  alias Curves.Utils.{Arc, Opts, Vec}

  @matrix [[1, 0, 0, 0], [-3, 3, 0, 0], [3, -6, 3, 0], [-1, 3, -3, 1]]

  # Takes {center, {rx, ry}}, since every spline type's define/2 takes one value plus options.
  @doc false
  @impl true
  def define({center, radii}, opts \\ []) do
    center = Vec.new(center)
    {rx, ry} = radii!(radii)
    opts = Opts.put_numbers!(opts, rotation: 0.0, from: 0.0, to: 360.0)
    [rotation, from, to] = Enum.map([:rotation, :from, :to], &radians(Keyword.fetch!(opts, &1)))
    arc = Arc.ellipse(center, rx, ry, rotation, from, to)

    Curves.define_spline([arc], :ellipse, opts)
  end

  @spec radians(float()) :: float()
  defp radians(degrees), do: degrees * :math.pi() / 180

  # Radii are {rx, ry}, two numbers that are 0 or more.
  @spec radii!(term()) :: {float(), float()}
  defp radii!({rx, ry}) when is_number(rx) and is_number(ry) and rx >= 0 and ry >= 0,
    do: {rx * 1.0, ry * 1.0}

  defp radii!(other) do
    raise ArgumentError,
          "the radii of an ellipse must be {rx, ry}, two numbers that are 0 or more, got: #{inspect(other)}"
  end

  @doc false
  @impl true
  def blending_function(), do: @matrix

  # The arc's hull points: see "Stored points" above.
  @doc false
  @impl true
  def stored_points([arc]), do: Arc.hull_points(arc)

  @doc false
  @impl true
  def control_lines([arc]), do: Arc.hull_lines(arc)

  @doc false
  @spec define_circle(T.point_tuple(), number(), T.opts()) :: Curves.Spline.Curve.t()
  def define_circle(center, r, opts \\ []) do
    r = radius!(r)
    define({center, {r, r}}, opts)
  end

  # A circle's radius: a number that is 0 or more.
  @spec radius!(term()) :: float()
  defp radius!(r) when is_number(r) and r >= 0, do: r * 1.0

  defp radius!(other) do
    raise ArgumentError,
          "the radius of a circle must be a number that is 0 or more, got: #{inspect(other)}"
  end
end
