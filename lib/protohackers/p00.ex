defmodule Protohackers.P00 do
  use GenServer

  require Logger

  defstruct [:listen_socket]

  def start_link([] = _args) do
    GenServer.start_link(__MODULE__, 7700)
  end

  @impl true
  def init(port_nr) do
    Logger.info("Starting #{__MODULE__} on port #{port_nr}")

    {:ok, listen_socket} = :gen_tcp.listen(port_nr, [:binary, reuseaddr: true, active: false])

    {:ok, %__MODULE__{listen_socket: listen_socket}, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)
    Logger.info("Accepted connection #{inspect(socket)}")
    spawn(fn -> handle_socket(socket) end)

    {:noreply, state, {:continue, :accept}}
  end

  defp handle_socket(socket) do
    :gen_tcp.recv(socket, 0)
    |> case do
      {:ok, message} ->
        Logger.info("Received #{byte_size(message)} bytes on socket #{inspect(socket)}")
        :gen_tcp.send(socket, message)
        handle_socket(socket)

      {:error, :closed} ->
        :gen_tcp.close(socket)
    end
  end
end
