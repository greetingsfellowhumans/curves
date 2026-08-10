defmodule Curves.Utils.OptsTest do
  use ExUnit.Case
  alias Curves.Utils.Opts, as: Mod
  import Mod
  # doctest Mod

  describe "Opts" do
    test "get the correct options" do
      opts = merge_opts([])
      assert Keyword.get(opts, :float_dtype) == 16

      opts = merge_opts(float_dtype: 8)
      assert Keyword.get(opts, :float_dtype) == 8
    end
  end
end
