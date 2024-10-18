defmodule P01Test do
  use ExUnit.Case
  doctest Protohackers.P01

  test "primality" do
    import Protohackers.P01

    assert is_prime(2) == true
    assert is_prime(3) == true
    assert is_prime(4) == false
    assert is_prime(5) == true
    assert is_prime(6) == false
    assert is_prime(7) == true
    assert is_prime(8) == false
    assert is_prime(9) == false
    assert is_prime(10) == false
    assert is_prime(11) == true

    assert is_prime(-3) == false
    assert is_prime(2.1) == false
  end

  test "single message" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":2}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == true

    :gen_tcp.close(socket)
  end

  test "multi message" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":5}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == true

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":8}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == false

    :gen_tcp.close(socket)
  end

  test "concat message" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":5}\n{\"method\":\"isPrime\",\"number\":8}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == true
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == false

    :gen_tcp.close(socket)
  end

  test "malformed" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":8}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == false

    :ok = :gen_tcp.send(socket, "aaaaaaaa\n")
    {:ok, "malformed json\n"} = :gen_tcp.recv(socket, 0, 100)

    :gen_tcp.close(socket)
  end

  test "non-natural" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":1.1}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == false

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":-2}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == false

    :gen_tcp.close(socket)
  end

  test "malformed2" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":true}\n")
    {:ok, "missing fields" <> _} = :gen_tcp.recv(socket, 0, 100)

    :gen_tcp.close(socket)
  end

  test "extra fields" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":8,\"extra\":true,\"extra2\":11}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 100)
    assert get_response_prime(message) == false

    :gen_tcp.close(socket)
  end

  test "long json" do
    socket = connect()

    :ok = :gen_tcp.send(socket, "{\"method\":\"isPrime\",\"number\":1234,\"garbage\":\"#{Enum.join(1..1000, "")}\"}\n")
    {:ok, message} = :gen_tcp.recv(socket, 0, 1000)
    assert get_response_prime(message) == false

    :gen_tcp.close(socket)
  end

  defp get_response_prime(message) do
    %{"method" => "isPrime", "prime" => prime} = :json.decode(message)
    prime
  end

  defp connect do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 7701, [:binary, active: false, packet: :line])
    socket
  end
end
