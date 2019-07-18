defmodule DxClusterEx.ArClient do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    with callsign <- Application.get_env(:dx_cluster_ex, :ar_callsign, 'KD0DEP'),
         server <- Application.get_env(:dx_cluster_ex, :ar_server, 'dxc.nc7j.com'),
         port <- Application.get_env(:dx_cluster_ex, :ar_port, 23) do
      {:ok,
       %{
         callsign: callsign,
         server: server,
         port: port,
         socket: nil,
         reconnect_attempts: 0,
         status: :disconnected
       }}
    end
  end

  # Client API

  def connect do
    GenServer.call(__MODULE__, {:connect})
  end

  def connect(callsign, server, port) do
    GenServer.call(__MODULE__, {:connect, callsign, server, port})
  end

  def close do
    GenServer.call(__MODULE__, {:close})
  end

  def clear_dx_filter do
    GenServer.call(__MODULE__, {:clear_dx_filter})
  end

  # Server API

  def handle_call({:connect}, _from, state) do
    state = process_connect(state)

    {:reply, :ok, state}
  end

  def handle_call({:connect, callsign, server, port}, _from, state) do
    state = process_connect(%{state | callsign: callsign, server: server, port: port})

    {:reply, :ok, state}
  end

  def handle_call({:close}, _from, state) do
    Logger.info("Closing ArClient connection to #{state.server}:#{state.port}")
    :ok = :gen_tcp.close(state.socket)
    {:reply, :ok, %{state | socket: nil, status: :disconnected}}
  end

  def handle_call({:clear_dx_filter}, _from, state) do
    :gen_tcp.send(state.socket, 'set dx filter\n')
    {:reply, :ok, state}
  end

  defp process_connect(state) do
    %{callsign: callsign, server: server, port: port} = state
    Logger.info("Attempting to connect to #{server}:#{port} as #{callsign}")

    {:ok, socket} =
      :gen_tcp.connect(server, port, [:binary, active: true, packet: :line, keepalive: true])

    %{state | socket: socket}
  end

  def handle_info({:tcp, _socket, packet}, state) do
    Logger.info("Handling incoming packet.")

    cond do
      state.status == :disconnected ->
        {:noreply, process_login(packet, state)}

      state.status == :connecting ->
        {:noreply, process_logging_in(packet, state)}

      state.status == :connected ->
        {:noreply, process_dx_spot(packet, state)}

      true ->
        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Connection to #{state.server}:#{state.port} closed.")
  end

  def handle_info({:tcp_error, _socket, :etimedout}, state) do
    Logger.info("Connection to #{state.server}:#{state.port} timed out.")
  end

  def terminate(_reason, state) do
    Logger.info("ArClient is shutting down.")
    unless is_nil(state.socket), do: :gen_tcp.close(state.socket)
  end

  ###

  def process_login("Please enter your call:\r\n", state) do
    Logger.info("Processing login request...")
    :gen_tcp.send(state.socket, state.callsign ++ '\n')
    %{state | status: :connecting}
  end

  def process_login(_, state), do: state

  def process_logging_in("login: " <> _rest, state) do
    %{state | status: :connected}
  end

  def process_logging_in(_, state), do: state

  def process_dx_spot("DX de " <> _rest = packet, state) do
    packet
    |> DxClusterEx.DxSpot.parse()

    state
  end

  def process_dx_spot(_, state), do: state
end
