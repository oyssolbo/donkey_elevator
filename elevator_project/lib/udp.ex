defmodule UDP do
  @moduledoc """
  Module for implementing some quick-and-dirty UDP-functions
  """

  require Logger

  @doc """
  @local_port             Default port to open
  @broadcast_address      Address required to broadcast
  @default_timeout        How long to wait before resending [ms]
  """
  @local_port 20012
  @broadcast_address {255, 255, 255, 255}
  @default_timeout 500


  @doc """
  Function that opens socket at the port @local_port with the options
  set to [:binary, active: :false, reuseaddr: :true]

  RETURNS:                        IF:
  {:ok, socket}                   If socket opened
  {:error, 0}                     If an error occured
  """
  def open_connection() do
    open_connection(@local_port)
  end

  @doc """
  Function that opens socket at the port 'port'

  port   Port to be opened. Must be integer
  opts   Options for the port. Must be a list. If none given, defaults to
                  [:binary, active: :false, reuseaddr: :true]

  RETURNS:                        IF:
  {:ok, socket}                   If socket opened
  {:error, 0}                     If an error occured
  """
  def open_connection(
        port,
        opts \\ [:binary, active: :false, reuseaddr: :true])
  when port |> is_integer and opts |> is_list
  do

    case :gen_udp.open(port, opts) do
      {:ok, socket} ->
        IO.puts("Opened port on port #{port}")
        {:ok, socket}
      {:error, _reason} ->
        IO.puts("An error occurred when opening the port #{port}")
        Logger.error("An error occurred when opening the port #{port}")
        {:nil, 0}
    end
  end

  @doc """
  Function that sends data

  from_socket  Socket to send from
  to_socket    Socket to send to
  packet       Data to be sent between the sockets


  RETURNS:                        IF:
  {:ok, socket}                   If socket opened
  {:nil, 0}                       If an error occured
  """
  def send_data(
        from_socket,
        to_address,
        port,
        packet)
  do
    Logger.info("Sent packet #{packet} to port #{port} on address #{to_address}")
    :gen_udp.send(from_socket, to_address, port, packet)
  end

  def send_data(
        from_socket,
        port,
        packet)
  do
    Logger.info("Sent packet #{packet} to port #{port} on local ip")
    :gen_udp.send(from_socket, @local_ip, port, packet)
  end


  @doc """
  Function for reading data received on a socket

  socket Socket to analyze new data

  RETURNS:                        IF:
  {:recv, recv_packet}            If packet received
  {:nil, 0}                       If an error occured
  """
  def receive_data(socket)
  do
    case :gen_udp.recv(socket, 0, @default_timeout) do
      {:ok, recv_packet} ->
        Logger.info("Received #{recv_packet} on #{socket}")
        {:recv, recv_packet}

      {:error, reason} ->
        Logger.error("Error occurred when recv packet")
        {:nil, 0}
    end
  end


  @doc """
  Function closing socket

  socket Socket to close
  """
  def close_socket(socket)
  do
    :gen_udp.close(socket)
  end

end
