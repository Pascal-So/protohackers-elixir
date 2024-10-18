defmodule P02Test do
  use ExUnit.Case
  doctest Protohackers.P02

  test "db test" do
    socket = connect()

    send_insert(socket, 1, 2)
    send_query(socket, 1, 1)
    assert get_response(socket) == 2
    send_query(socket, 2, 3)
    assert get_response(socket) == 0

    send_insert(socket, 2, 4)
    send_query(socket, 2, 3)
    assert get_response(socket) == 4
    send_query(socket, 1, 3)
    assert get_response(socket) == 3

    :gen_tcp.close(socket)
  end

  defp send_insert(socket, timestamp, price) do
    m = <<"I", timestamp::32-big, price::32-big>>
    :ok = :gen_tcp.send(socket, m)
  end

  defp send_query(socket, mintime, maxtime) do
    m = <<"Q", mintime::32-big, maxtime::32-big>>
    :ok = :gen_tcp.send(socket, m)
  end

  defp get_response(socket) do
    {:ok, <<avg::32-signed-big>>} = :gen_tcp.recv(socket, 0, 100)
    avg
  end

  defp connect do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 7702, [:binary, active: false])
    socket
  end
end
