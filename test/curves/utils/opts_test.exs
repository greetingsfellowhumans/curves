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

    test "merge_opts/2 reads the app config, and given opts beat it" do
      Application.put_env(:curves, :force_percent, true)
      on_exit(fn -> Application.delete_env(:curves, :force_percent) end)
      assert merge_opts([])[:force_percent] == true
      assert merge_opts(force_percent: false)[:force_percent] == false
    end

    test "put_force_percent/2: an explicit nil wins over the app config" do
      Application.put_env(:curves, :force_percent, true)
      on_exit(fn -> Application.delete_env(:curves, :force_percent) end)
      assert put_force_percent([], [])[:force_percent] == true
      assert put_force_percent([force_percent: nil], [])[:force_percent] == nil
      assert put_force_percent([], force_percent: nil)[:force_percent] == nil
    end
  end
end
