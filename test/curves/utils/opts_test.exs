defmodule Curves.Utils.OptsTest do
  use ExUnit.Case
  alias Curves.Utils.Opts, as: Mod
  import Mod
  # doctest Mod

  describe "Opts" do
    test "fills in :force_percent, and given opts win" do
      assert Keyword.get(merge_opts([]), :force_percent) == false
      assert Keyword.get(merge_opts(force_percent: true), :force_percent) == true
    end

    test "put_force_percent/2: call opts, then define opts, then the default" do
      assert put_force_percent([force_percent: true], force_percent: false)[:force_percent] ==
               false

      assert put_force_percent([force_percent: true], [])[:force_percent] == true
      assert put_force_percent([], [])[:force_percent] == false
    end
  end
end
