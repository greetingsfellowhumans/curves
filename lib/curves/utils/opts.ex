defmodule Curves.Utils.Opts do
  @moduledoc false
  @config_opts [
    float_dtype: %{default: 32, doc: "The default bitsize for floats.", one_of: [8, 16, 32, 64]},
    force_percent: %{
      default: false,
      doc:
        "If true, `take` and `solve` rescale each coordinate so the lowest point on that axis is 0.0 and the highest is 1.0, measured after any moves, scaling or rotation. A flat axis, where every point has the same value, returns that value as-is. Beziers read this config on every `solve`/`take`; splines read it when they are defined or transformed.",
      one_of: [true, false]
    }
  ]

  def merge_opts(user_opts, default_opts \\ [])
      when is_list(user_opts) and is_list(default_opts) do
    default_opts
    |> Keyword.merge(config_opts())
    |> Keyword.merge(user_opts)
  end

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
