defmodule P00Test do
  use ExUnit.Case
  doctest Protohackers.P00

  test "single client" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "hello world")
    {:ok, "hello world" } = :gen_tcp.recv(socket, 0, 100)
    :gen_tcp.close(socket)
  end

  test "multi client" do
    socket_a = connect()
    socket_b = connect()

    :ok = :gen_tcp.send(socket_a, "1")
    {:ok, "1" } = :gen_tcp.recv(socket_a, 0, 100)

    :ok = :gen_tcp.send(socket_b, "2")
    {:ok, "2" } = :gen_tcp.recv(socket_b, 0, 100)

    :ok = :gen_tcp.send(socket_a, "3")
    {:ok, "3" } = :gen_tcp.recv(socket_a, 0, 100)

    :gen_tcp.close(socket_b)

    :ok = :gen_tcp.send(socket_a, "4")
    {:ok, "4" } = :gen_tcp.recv(socket_a, 0, 100)

    :gen_tcp.close(socket_a)
  end

  defp connect do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 7700, [:binary, active: false])
    socket
  end
end
