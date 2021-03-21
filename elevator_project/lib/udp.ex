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
  @brief        Function that opens socket at the port @local_port

  @retval       RETURNS:                        IF:
                  {:ok, socket}                 If socket opened
                  {:nil, 0}                     If an error occured
  """
  def open_connection() do
    open_connection(@local_port)
  end

  @doc """
  @brief        Function that opens socket at the port @local_port

  @param port   Port to be opened. Must be integer
  @param opts   Options for the port. Must be a list. If none given, defaults to
                  [:binary, active: :false, reuseaddr: :true]

  @retval       RETURNS:                        IF:
                  {:ok, socket}                 If socket opened
                  {:nil, 0}                     If an error occured
  """
  def open_connection(port, opts \\ [:binary, active: :true, reuseaddr: :true])
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
  @brief        Function that sends data

  @param from_socket  Socket to send from
  @param to_socket    Socket to send to
  @param packet       Data to be sent between the sockets


  @retval       RETURNS:                        IF:
                  {:ok, socket}                 If socket opened
                  {:nil, 0}                     If an error occured
  """
  def send_data(from_socket, to_socket, packet) do
        #when from_socket |> is_tuple and to_socket |> is_tuple
    Logger.info("Sent packet #{packet} from #{from_socket} to #{to_socket}")
    :gen_udp.send(from_socket, to_socket, packet)
  end


  def send_data(from_socket, ip, port, packet) do
    #when from_socket |> is_tuple and to_socket |> is_tuple do
    #Logger.info("Sent packet #{packet} from #{from_socket} to #{ip} on port #{port}")
    :gen_udp.send(from_socket, ip, port, packet)
end



  @doc """
  @brief        Function to handle if not correct socket-syntax
  """
  def send_data(_, _, _) do
    IO.puts("The values 'from_socket' and 'to_socket' must be tuples")
    Logger.error("The values 'from_socket' and 'to_socket' must be tuples")
  end


  @doc """
  @brief        Function for reading data received on a socket

  @param socket Socket to analyze new data

  @retval       RETURNS:                        IF:
                  {:recv, recv_packet}          If packet received
                  {:nil, 0}                     If an error occured
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
  @brief        Function closing socket

  @param socket Socket to close
  """
  def close_socket(socket) do
    :gen_udp.close(socket)
  end

end
