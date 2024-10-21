defmodule Protohackers.P03 do
  use GenServer

  require Logger

  defstruct [:listen_socket, :users_agent]

  def start_link([] = _args) do
    GenServer.start_link(__MODULE__, 7703)
  end

  @impl true
  def init(port_nr) do
    Logger.info("Starting #{__MODULE__} on port #{port_nr}")

    {:ok, listen_socket} =
      :gen_tcp.listen(port_nr, [
        :binary,
        reuseaddr: true,
        packet: :line,
        buffer: 1_000_000,
        active: false
      ])

    {:ok, users_agent} = Agent.start_link(fn -> %{} end)

    state = %__MODULE__{
      listen_socket: listen_socket,
      users_agent: users_agent
    }

    {:ok, state, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)
    Logger.info("Accepted connection #{inspect(socket)}")
    spawn(fn -> handle_welcome_phase(socket, state.users_agent) end)

    {:noreply, state, {:continue, :accept}}
  end

  defp valid_name?(name) do
    byte_size(name) > 0 and String.match?(name, ~r/^[0-9a-zA-Z]+$/)
  end

  defp handle_welcome_phase(socket, users_agent) do
    :gen_tcp.send(socket, "* Welcome, please type your name\n")

    :gen_tcp.recv(socket, 0, 30_000)
    |> case do
      {:ok, name} ->
        if valid_name?(name) do
          name = String.trim_trailing(name, "\n")
          users = Agent.get(users_agent, & &1)

          Logger.debug("Received name #{name}, currently online: #{inspect(Map.keys(users))}")

          if name in users do
            :gen_tcp.send(socket, "* name already taken.\n")
            :gen_tcp.close(socket)
          else
            Agent.update(users_agent, &Map.put(&1, name, socket))
            :gen_tcp.send(socket, ["* The users are: ", Enum.join(Map.keys(users), ", "), "\n"])

            send_to_other_users(users_agent, name, ["* ", name, " has joined the chat\n"])

            handle_client(socket, name, users_agent)
          end
        else
          Logger.debug("Received invalid name #{name}")
          :gen_tcp.send(socket, "* invalid name.\n")
          :gen_tcp.close(socket)
        end

      {:error, :timeout} ->
        Logger.debug("Connection timed out")

      {:error, :closed} ->
        :gen_tcp.close(socket)
    end
  end

  defp handle_client(socket, name, users_agent) do
    :gen_tcp.recv(socket, 0, 30_000)
    |> case do
      {:ok, msg} ->
        msg = String.trim_trailing(msg, "\n")
        Logger.debug("Received message #{msg} from user #{name}")
        send_to_other_users(users_agent, name, ["[", name, "] ", msg, "\n"])
        handle_client(socket, name, users_agent)

      {:error, :timeout} ->
        handle_client(socket, name, users_agent)

      {:error, :closed} ->
        Logger.debug("Connection closed for user #{name}")
        send_to_other_users(users_agent, name, ["* ", name, " left the chat\n"])
        Agent.update(users_agent, &Map.delete(&1, name))
        :gen_tcp.close(socket)
    end
  end

  defp send_to_other_users(users_agent, my_name, msg) do
    Agent.get(users_agent, & &1)
    |> Enum.each(fn {name, socket} ->
      if name != my_name do
        Logger.debug("Sending message #{inspect(msg)} to user #{name}")
        :gen_tcp.send(socket, msg)
      end
    end)
  end
end
