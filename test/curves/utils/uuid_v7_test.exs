defmodule Curves.Utils.UuidV7Test do
  use ExUnit.Case
  alias Curves.Utils.UuidV7, as: Mod
  import Mod
  # doctest Mod

  describe "UuidV7" do
    setup ctx do
      ids =
        for _ <- 0..50 do
          generate_uuid_v7()
        end

      Map.put(ctx, :ids, ids)
    end

    test "uuids are unique", %{ids: ids} do
      assert Enum.count(ids) == MapSet.size(MapSet.new(ids))
    end

    test "uuids are 128 bit", %{ids: ids} do
      [id | _] = ids
      assert bit_size(id) == 128
    end

    test "uuids are time ordered", _ do
      id1 = generate_uuid_v7()
      Process.sleep(2)
      id2 = generate_uuid_v7()
      Process.sleep(2)
      id3 = generate_uuid_v7()
      Process.sleep(2)
      id4 = generate_uuid_v7()
      Process.sleep(2)
      id5 = generate_uuid_v7()
      Process.sleep(2)
      id6 = generate_uuid_v7()
      Process.sleep(2)
      ids = [id1, id2, id3, id4, id5, id6]
      assert Enum.sort(ids) == ids
    end
  end
end
