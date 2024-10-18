defmodule Protohackers.P01 do
  use GenServer

  require Logger

  defstruct [:listen_socket]

  def start_link([] = _args) do
    GenServer.start_link(__MODULE__, 7701)
  end

  @impl true
  def init(port_nr) do
    Logger.info("Starting #{__MODULE__} on port #{port_nr}")

    {:ok, listen_socket} =
      :gen_tcp.listen(port_nr, [:binary, reuseaddr: true, active: false, packet: :line, buffer: 1_000_000])

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
    :gen_tcp.recv(socket, 0, 3_000)
    |> case do
      {:ok, message} ->
        Logger.debug("Received: #{message}")
        {status, response} = handle_message(message)
        Logger.debug("Response: #{response}")
        :gen_tcp.send(socket, [response, "\n"])

        case status do
          :ok ->
            handle_socket(socket)

          :err ->
            :gen_tcp.close(socket)
        end

      {:error, :closed} ->
        :gen_tcp.close(socket)
    end
  end

  defp handle_message(message) do
    try do
      case :json.decode(message) do
        %{"method" => "isPrime", "number" => number} when is_number(number) ->
          {:ok, :json.encode(%{"method" => "isPrime", "prime" => is_prime(number)})}

        e ->
          {:err, "missing fields: #{inspect(e)}"}
      end
    rescue
      _ ->
        {:err, "malformed json"}
    end
  end

  def is_prime(number) do
    cond do
      not is_integer(number) ->
        false

      number < 2 ->
        false

      number in [2, 3] ->
        true

      true ->
        limit = floor(:math.sqrt(number))

        2..limit
        |> Enum.all?(&(rem(number, &1) != 0))
    end
  end
end
