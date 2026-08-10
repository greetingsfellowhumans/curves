defmodule Curves.Utils.UuidV7 do
  @moduledoc false

  def generate_uuid_v7() do
    ms = System.system_time(:millisecond)
    <<u1::12, u2::62, _::6>> = :crypto.strong_rand_bytes(10)
    <<ms::48, 7::4, u1::12, 2::2, u2::62>>
  end
end
