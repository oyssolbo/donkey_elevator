defmodule UDP_discover do
  @moduledoc """
  Module giving basic functions for using networking


  -UDP
  """

  require Logger

  @broadcast_address {255, 255, 255, 255}
  @broadcast_port 9876
  @init_port 6789
  @num_tries 5
  @default_timeout 15000

  @doc """
  @brief        Function that hopefully returns the IP-address of the system


  @param port   Port we should try to access. Default param set to @init_port

  @retval       RETURNS:                        IF:
                  ip                              If the IP-address was found
                  {:error, :could_not_get_ip}     If the IP-address could not be
                                                    resolved
  """
  def get_ip(port \\ @init_port) do
    case UDP.open_connection(port, [active: false, broadcast: true]) do
      {:ok, socket} ->
        #UDP.send_data(socket, @broadcast_address, port, "Test")
        :gen_udp.send(socket, {255,255,255,255}, 6789, "test packet")
        # case UDP.receive_data(socket) do
        #   {:recv, {ip, _port, _data}} ->
        #     {:recv, ip}
        #   {:error, _} ->
        #     {:error, :could_not_get_ip}
        # end

        ip = case :gen_udp.recv(socket, 100, 1000) do
          {:ok, {ip, _port, _data}} -> ip
          {:error, _} -> {:error, :could_not_get_ip}
        end

        UDP.close_socket(socket)
        :inet.ntoa(ip) |> to_string()

        {:nil, _} ->
          if port - @init_port < @num_tries do
            get_ip(port + 1)
          else
            Logger.error("Could not find ip-address")
            {:error, :could_not_get_ip}
          end
    end
  end

  @doc """
  @brief        Helper function to open UDP socket on the broadcast port with the broadcast options
  """
  def broadcast_open_connection(port \\ @broadcast_port)
  do
    case UDP.open_connection(port, [active: false, broadcast: true, reuseaddr: :true]) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end


  @doc """
  @brief        Function that will broadcast the node_name on the broadcast port
                It will spawn it's own process for looping in infinity
  """
  def broadcast_cast(node_name, port \\ @broadcast_port)
  do
    case broadcast_open_connection() do
      {:ok, socket} ->
        #:gen_udp.send(socket, @broadcast_address, @broadcast_port, node_name)
        spawn (fn -> broadcast_cast_loop(node_name,socket) end)
      {:error, reason} ->
        Logger.error("The error #{reason} occured while trying to broadcast #{node_name}")
    end
  end

  @doc """
  @brief        Function that will broadcast the node_name on the broadcast port
                will loop in infinity
  """
  def broadcast_cast_loop(node_name, socket, port \\ @broadcast_port)
  do
      :gen_udp.send(socket, @broadcast_address, @broadcast_port, node_name)
      Process.sleep(@default_timeout)
      broadcast_cast_loop(node_name,socket)
  end


  @doc """
  @brief        Function that will receive node_name from the broadcast_cast function above, and connect to the node, should be called at master init
  """
  def broadcast_listen(port \\ @broadcast_port)
    do
      case broadcast_open_connection() do
        {:ok, socket} ->
          spawn( fn -> broadcast_receive_and_connect(socket) end)
      end
    end


@doc """
@brief Helper function tp broadcast_receive and connect
"""
  def broadcast_receive_and_connect(socket)
    do
      case :gen_udp.recv(socket, 0)  do
        {:ok, recv_packet} ->
          data = Kernel.elem(recv_packet, 2)
          Logger.info("Connecting to the node #{data}")
          Node.ping(String.to_atom(to_string(data)))

        {:error, reason} ->
          Logger.error("Failed to receive due to #{reason}")
      end
      broadcast_receive_and_connect(socket) # While loop to keep the tread alive and alway listeninng for new connection
    end
end
