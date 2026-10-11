defmodule Curves.Utils.Opts do
  @moduledoc false
  alias Curves.Types, as: T

  @config_opts [
    float_dtype: %{default: 32, doc: "The default bitsize for floats.", one_of: [8, 16, 32, 64]},
    force_percent: %{
      default: false,
      doc:
        "If true, `take` and `solve` rescale each coordinate so the lowest point on that axis is 0.0 and the highest is 1.0, measured after any moves, scaling or rotation. A flat axis, where every point has the same value, returns 0.5. It is read on every `solve`/`take`, so changing it while running applies straight away.",
      one_of: [true, false]
    }
  ]

  # Fills in every config option. Precedence: user_opts, then the app config, then default_opts.
  @spec merge_opts(T.opts(), T.opts()) :: T.opts()
  def merge_opts(user_opts, default_opts \\ [])
      when is_list(user_opts) and is_list(default_opts) do
    default_opts
    |> Keyword.merge(config_opts())
    |> Keyword.merge(user_opts)
  end

  # Returns `call_opts` with :force_percent set to the value that applies right now.
  # Precedence: call_opts, then curve_opts (given at define), then the app config, then the default.
  # Called on every solve/take, so a change to the app config after define still applies.
  @spec put_force_percent(T.opts(), T.opts()) :: T.opts()
  def put_force_percent(curve_opts, call_opts) do
    force_percent =
      curve_opts
      |> Keyword.merge(call_opts)
      |> merge_opts()
      |> Keyword.get(:force_percent)

    Keyword.put(call_opts, :force_percent, force_percent)
  end

  # Each config option's value from the app config, or its default when it isn't set.
  @spec config_opts() :: T.opts()
  defp config_opts() do
    Enum.map(@config_opts, fn {k, %{default: d}} ->
      o =
        case Application.fetch_env(:curves, k) do
          {:ok, c} -> c
          :error -> d
        end

      {k, o}
    end)
  end
end
