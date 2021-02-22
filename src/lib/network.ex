defmodule Server do
  @moduledoc """
  The Server-module is the server that the master runs for controlling
  the elevators in the project.

  The module is supervised via a supervisor to make sure that the system
  experiences good concurrency.
  """

  # Require Logger to write a log instead of writing only to screen
  require Logger

  # Read parameters from a list of IP and PORT-addresses ( TODO )
  @default_server_port 20012
  @default_local_host {255, 255, 255, 255}
  @default_timeout 500


  @doc """
  Launches the server with an integer value for the port

  launch_server/0 defaults launch_server/1 to @default_server_port

  launch_server/1 takes in a port with value 'port' to launch the server
  at
  """
  def launch_server() do
    launch_server( @default_server_port )
  end


  def launch_server( port ) when port |> is_integer do
    # Gets a kernel-error when using binary: :true as an option
    case :gen_udp.open( @default_server_port, [ :binary, active: :false, reuseaddr: :true ] ) do
      { :ok, socket } ->
        IO.puts("Listening on port")
        listen( socket )

      { :error, reason } ->
        IO.puts( "Could not open the port #{port} due to #{reason}" )
        Logger.error( "Could not open the port #{port} due to #{reason}" )

    end
  end


  @doc """
  Shut down a socket if an error has occured
  """
  defp shut_down_socket( socket ) do
    :gen_udp.close( socket )
  end


  @doc """
  Listen for new messages. Spawn a new process to handle the data
  before
  """
  defp listen( socket ) do
    case :gen_udp.recv( socket, 0 ) do
      { :ok, recv_data } ->
        IO.puts("Data received")
        spawn( fn -> serve_message( recv_data, socket ) end )

      { :error, reason } ->
        Logger.error( "Error occured when listening on socket #{socket} due to #{reason}" )

    end

    listen( socket )
  end


  @doc """
  Serve any incomming message. This must be updated according to the
  requirements
  """
  defp serve_message( { :udp, _socket, ip, port, data }, socket ) do
    # Send an acknowledgement that the data is received
    IO.puts("Serving message")
    dest = { ip, port }
    result = factorial( String.to_integer( data ) )
    send_data( socket, dest, Integer.to_string( result ) )
  end


  defp serve_message( _, socket ) do
    Logger.error( "Unidentified message received" )
  end


  @doc """
  Calculating the factorial of the given number

  Just a random function to process the data given to the server. Must be
  replaced by a real function later
  """
  defp factorial( N ) when N <= 0 do
    1
  end

  defp factorial( N ) when N > 0 and N |> is_integer do
    N * factorial( N - 1 )
  end


  @doc """
  Function to send a package 'data' to a destination 'dest'.
  It is assumed that 'dest' is a tuple containing { ip-address, port }
  """
  defp send_data( socket, dest, data ) when socket |> is_tuple do
    :gen_udp.send( socket, dest, data )
  end
end


defmodule Client do
  @moduledoc """
  The Client-module implements the functions for the clients connecting to
  the server. Mainly used for the elevators connected to the masters
  """

  # Require Logger to write a log instead of writing only to screen
  require Logger

  # Read parameters from a list of IP and PORT-addresses ( TODO )
  @default_server_ip {127,0,0,1}
  @default_server_port 20013
  @default_timeout 1000

  @client_port @default_server_port + 1

  @doc """
  Function to initiate the port and connect to the server
  """
  def initiate_client() do
    case :gen_udp.open( @client_port, [:binary, active: :true, reuseaddr: :true] ) do
      { :ok, socket } ->
        IO.puts("Spawning")
        spawn( fn -> send_data( socket, 5 ) end )
        spawn( fn -> loop( socket ) end )


      { :error, reason } ->
        IO.puts( "Could not open the port due to #{reason}" )
        Logger.error( "Could not open the port due to #{reason}" )
    end
  end


  @doc """
  Loop to just check for connection to the server
  """
  defp loop( socket ) do
    case :gen_udp.recv( socket, 0 ) do
      {:ok, recv_data} ->
        IO.puts("Received data")

        { _, _, packet: packet } = recv_data

        IO.puts("Received the packet #{packet}")

      {:error, reason} ->
        loop(socket)
      end
  end

  @doc """
  Function to send an int to the server
  """
  defp send_data( socket, data ) when data |> is_integer and data >= 0 do
    ip = get_my_ip() |> ip_to_string() # Since on the same machine
    dest = { ip, @default_server_port }
    data_string = Integer.to_string( data )
    IO.puts("Trying to send data")

    case :gen_tcp.send( socket, dest, data_string ) do
      :ok ->
        send_data( socket, data - 1 )
        IO.puts("Sending data")
        :ok
      { :error, reason } ->
        IO.puts( "Error occured due to #{reason} under transmit" )
    end
  end

  defp get_my_ip(counter \\ 0) when counter < 11 do
    Process.sleep(100)

    if counter == 10 do
      IO.puts("Couldn't find my IP")
    end

    {:ok, socket} = :gen_udp.open(6199, active: false, broadcast: true)
    :ok = :gen_udp.send(socket, {255, 255, 255, 255}, 6199, "Test packet")

    ip =
      case :gen_udp.recv(socket, 100, 1000) do
        {:ok, {ip, _port, _data}} -> ip
        {:error, _} -> get_my_ip(counter + 1)
      end

    :gen_udp.close(socket)
    ip
  end

  defp ip_to_string(ip) do
    :inet.ntoa(ip) |> to_string()
  end
end
