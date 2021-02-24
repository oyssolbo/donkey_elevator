defmodule UDP do
  @moduledoc """
  Basic module for implementing some quick UDP-functions
  """


  require Logger


  @local_port 20012
  @broadcast_address {255, 255, 255, 255}
  @default_timeout 500


  @doc """
  Function for opening a standard port
  """
  def open_connection() do
    open_connection(@local_port)
  end


  @doc """
  Function for open a socket on port 'port' with options 'opts'
  """
  def open_connection(port, opts \\ [:binary, active: :false, reuseaddr: :true])
        when port |> is_integer and opts |> is_list do

    case :gen_udp.open(port, opts) do
      {:ok, socket} ->
        IO.puts("Opened port on port #{port}")
        {:ok, socket}
      {:error, reason} ->
        IO.puts("An error occurred when opening the port #{port}")
        Logger.error("An error occurred when opening the port #{port}")
        {:nil, 0}
    end
  end


  @doc """
  Function for sending the packet 'packet' from 'from_socket' to 'to_socket'
  """
  def send_data(from_socket, to_socket, packet) when from_socket |> is_tuple do
    Logger.info("Sent packet #{packet} from #{from_socket} to #{to_socket}")
    :gen_udp.send(from_socket, to_socket, packet)
  end


  @doc """
  Function that handles if we are not given correct socket-syntax
  """
  def send_data(_, _, _) do
    IO.puts("The values 'from_socket' and 'to_socket' must be tuples")
    Logger.error("The values 'from_socket' and 'to_socket' must be tuples")
  end


  @doc """
  Function for reading local data
  """
  def receive_data(socket) do
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
  Function for closing the socket 'socket'
  """
  def close_socket(socket) do
    :gen_udp.close(socket)
  end

end
