defmodule Protohackers.P02 do
  use GenServer

  require Logger

  defstruct [:listen_socket]

  def start_link([] = _args) do
    GenServer.start_link(__MODULE__, 7702)
  end

  @impl true
  def init(port_nr) do
    Logger.info("Starting #{__MODULE__} on port #{port_nr}")

    {:ok, listen_socket} =
      :gen_tcp.listen(port_nr, [:binary, reuseaddr: true, active: false])

    {:ok, %__MODULE__{listen_socket: listen_socket}, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    {:ok, socket} = :gen_tcp.accept(state.listen_socket)
    Logger.info("Accepted connection #{inspect(socket)}")
    spawn(fn -> handle_client(socket, []) end)

    {:noreply, state, {:continue, :accept}}
  end

  defp handle_client(socket, db) do
    :gen_tcp.recv(socket, 9, 30_000)
    |> case do
      {:ok, <<"I", timestamp::32-signed-big, price::32-signed-big>>} ->
        Logger.debug("Received insert #{timestamp} #{price}")
        handle_client(socket, [{timestamp, price} | db])

      {:ok, <<"Q", mintime::32-signed-big, maxtime::32-signed-big>>} ->
        Logger.debug("Received query #{mintime} #{maxtime}")

        {sum, count} = Enum.reduce(db, {0, 0}, fn {timestamp, price}, {sum, count} ->
          if mintime <= timestamp and timestamp <= maxtime do
            {sum + price, count + 1}
          else
            {sum, count}
          end
        end)

        average = if count == 0 do
          0
        else
          div(sum, count)
        end
        :gen_tcp.send(socket, <<average::32-signed-big>>)

        handle_client(socket, db)

      {:error, :closed} ->
        :gen_tcp.close(socket)
    end
  end
end
