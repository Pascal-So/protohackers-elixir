defmodule P03Test do
  use ExUnit.Case
  doctest Protohackers.P03

  test "can connect" do
    socket = connect()
    :gen_tcp.close(socket)
  end

  test "receives welcome message" do
    socket = connect()
    msg = get_message(socket)
    assert(String.length(msg) > 2)
    :gen_tcp.close(socket)
  end

  test "rejects empty name" do
    socket = connect()
    _ = get_message(socket)
    :gen_tcp.send(socket, "a b c\n")
    _ = get_message(socket)
    {:error, :closed} = :gen_tcp.recv(socket, 0, 100)
    :gen_tcp.close(socket)
  end

  test "sees presence of other user" do
    username_a = "userA"
    username_b = "userB"

    socket_a = connect()
    _ = get_message(socket_a)
    :gen_tcp.send(socket_a, [username_a, "\n"])
    msg = get_message(socket_a)
    assert(String.starts_with?(msg, "*"))

    socket_b = connect()
    _ = get_message(socket_b)
    :gen_tcp.send(socket_b, [username_b, "\n"])
    msg = get_message(socket_b)
    assert(String.starts_with?(msg, "*"))
    assert(String.contains?(msg, username_a))
  end

  test "joining is announced" do
    username_a = "userA"
    username_b = "userB"

    socket_a = connect()
    _ = get_message(socket_a)
    :gen_tcp.send(socket_a, [username_a, "\n"])
    _ = get_message(socket_a)

    socket_b = connect()
    _ = get_message(socket_b)
    :gen_tcp.send(socket_b, [username_b, "\n"])
    _ = get_message(socket_b)

    join_notification = get_message(socket_a)
    assert(String.starts_with?(join_notification, "*"))
    assert(String.contains?(join_notification, username_b))
  end

  test "leaving is announced" do
    username_a = "userA"
    username_b = "userB"

    socket_a = connect()
    _ = get_message(socket_a)
    :gen_tcp.send(socket_a, [username_a, "\n"])
    _ = get_message(socket_a)

    socket_b = connect()
    _ = get_message(socket_b)
    :gen_tcp.send(socket_b, [username_b, "\n"])
    _ = get_message(socket_b)

    _join_notification = get_message(socket_a)

    :gen_tcp.close(socket_b)

    leave_notification = get_message(socket_a)
    assert(String.starts_with?(leave_notification, "*"))
    assert(String.contains?(leave_notification, username_b))
  end

  test "messages are sent only to others" do
    username_a = "userA"
    username_b = "userB"

    socket_a = connect()
    _ = get_message(socket_a)
    :gen_tcp.send(socket_a, [username_a, "\n"])
    _ = get_message(socket_a)

    socket_b = connect()
    _ = get_message(socket_b)
    :gen_tcp.send(socket_b, [username_b, "\n"])
    _ = get_message(socket_b)

    _join_notification = get_message(socket_a)

    :gen_tcp.send(socket_b, "hello\n")
    msg = get_message(socket_a)
    assert(msg == "[" <> username_b <> "] hello\n")

    {:error, :timeout} = :gen_tcp.recv(socket_a, 0, 100)
    {:error, :timeout} = :gen_tcp.recv(socket_b, 0, 100)

    :gen_tcp.send(socket_a, "hello back\n")
    msg = get_message(socket_b)
    assert(msg == "[" <> username_a <> "] hello back\n")
  end

  test "handle multiple messages" do
    username_a = "userA"
    username_b = "userB"

    socket_a = connect()
    _ = get_message(socket_a)
    :gen_tcp.send(socket_a, [username_a, "\n"])
    _ = get_message(socket_a)

    socket_b = connect()
    _ = get_message(socket_b)
    :gen_tcp.send(socket_b, [username_b, "\n"])
    _ = get_message(socket_b)

    _join_notification = get_message(socket_a)

    :gen_tcp.send(socket_a, "1\n")
    msg = get_message(socket_b)
    assert(msg == "[" <> username_a <> "] 1\n")

    {:error, :timeout} = :gen_tcp.recv(socket_a, 0, 100)
    {:error, :timeout} = :gen_tcp.recv(socket_b, 0, 100)

    :gen_tcp.send(socket_a, "2\n")
    msg = get_message(socket_b)
    assert(msg == "[" <> username_a <> "] 2\n")

    {:error, :timeout} = :gen_tcp.recv(socket_a, 0, 100)
    {:error, :timeout} = :gen_tcp.recv(socket_b, 0, 100)
  end

  test "leaving users are removed from the list" do
    username_a = "userA"
    username_b = "userB"
    username_c = "userC"

    socket_a = connect()
    _ = get_message(socket_a)
    :gen_tcp.send(socket_a, [username_a, "\n"])
    _ = get_message(socket_a)

    socket_b = connect()
    _ = get_message(socket_b)
    :gen_tcp.send(socket_b, [username_b, "\n"])
    _ = get_message(socket_b)

    _join_notification = get_message(socket_a)

    :gen_tcp.close(socket_b)

    _leave_notification = get_message(socket_a)

    socket_c = connect()
    _ = get_message(socket_c)
    :gen_tcp.send(socket_c, [username_c, "\n"])

    users_list = get_message(socket_c)

    assert(String.starts_with?(users_list, "*"))
    assert(String.contains?(users_list, username_a))
    assert(not String.contains?(users_list, username_b))
    assert(not String.contains?(users_list, username_c))
  end

  defp get_message(socket) do
    {:ok, msg} = :gen_tcp.recv(socket, 0, 100)
    msg
  end

  defp connect do
    {:ok, socket} =
      :gen_tcp.connect({127, 0, 0, 1}, 7703, [
        :binary,
        active: false,
        packet: :line,
        buffer: 1_000_000
      ])

    socket
  end
end
