defmodule Curves.Support.SampleCurves do

  @curve0 [
    # P0
    [{5.0, 10.0},
      {10.0, 10.0}
    ],

    # P1
    [
     {10.0, 5.0},
     {5.0, 5.0},
    ],
  ]

  @curve1 [
    # P0
    [{5.0, 10.0},
      {10.0, 10.0}
    ],

    # P1
    [{10.0, 5.0},
     {5.0, 5.0},
     {15.0, 5.0}],

    # P2
    [{15.0, 10.0},
     {15.0, 6.0},
     {15.0, 14.0 }],

    # P3
    [{20.0, 15.0},
     {16.0, 15.0},
     {23.0, 15.0}],

    # P4
    [{25.0, 10.0},
     {20.0, 10.0}]
  ]
  @hermite [
    # P0
    [{5.0, 10.0}],

    # P1
    [{10.0, 5.0}],

    # P2
    [{15.0, 10.0}],

    # P3
    [{20.0, 15.0}],

    # P4
    [{25.0, 10.0}],

  ]
  def with_curves(ctx) do
    ctx
      |> Map.put(:curves, %{
      curve0: Curves.define_spline(@curve0, :bezier_spline),
      curve1: Curves.define_spline(@curve1, :bezier_spline),
      #hermite0: Curves.define_spline(@hermite, :hermite),
    })
      |> Map.put(:curve_specs, %{
      curve0: @curve0,
      curve1: @curve1,
      hermite0: @hermite
    })
  end
end
