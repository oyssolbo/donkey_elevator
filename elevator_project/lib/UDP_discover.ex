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
  @default_timeout 45000 #increased for testing purposes (easier to debug)

  @doc """
  @brief        Function that hopefully returns the IP-address of the system


  @param port   Port we should try to access. Default param set to @init_port

  @retval       RETURNS:                        IF:
                  ip                              If the IP-address was found
                  {:error, :could_not_get_ip}     If the IP-address could not be
                                                    resolved
  """
  def get_ip(port \\ @init_port) do
    case :gen_udp.open(port, [active: false, broadcast: true]) do
      {:ok, socket} ->
        :gen_udp.send(socket, @broadcast_address, port, "test packet")

        ip = case :gen_udp.recv(socket, 100, 1000) do
          {:ok, {ip, _port, _data}} -> ip
          {:error, _} -> {:error, :could_not_get_ip}
        end

        :gen_udp.close(socket)
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
  def broadcast_open_socket(port \\ @broadcast_port)
  do
    case :gen_udp.open(port, [active: false, broadcast: true, reuseaddr: :true]) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, reason} ->
        Logger.error("An error occurred when opening the port #{port}")
        {:error, reason}
    end
  end


  @doc """
  @brief        Function that will broadcast the node_name on the broadcast port
                It will spawn it's own process for looping in infinity
  """
  def broadcast_cast(node_name, port \\ @broadcast_port)
  do
    case broadcast_open_socket() do
      {:ok, socket} ->
        #:gen_udp.send(socket, @broadcast_address, @broadcast_port, node_name)
        spawn (fn -> broadcast_cast_loop(node_name, socket, port) end)
      {:error, reason} ->
        Logger.error("The error #{reason} occured while trying to broadcast #{node_name}")
    end
  end

  @doc """
  @brief        Function that will broadcast the node_name on the broadcast port
                will loop in infinity
  """
  defp broadcast_cast_loop(node_name, socket, port)
  do
      :gen_udp.send(socket, @broadcast_address, port, node_name)
      Process.sleep(@default_timeout)
      broadcast_cast_loop(node_name,socket, port)
  end


  @doc """
  @brief        Function that will receive node_name from the broadcast_cast function above, and connect to the node, should be called at master init
  """
  def broadcast_listen(port \\ @broadcast_port)
    do
      case broadcast_open_socket(port) do
        {:ok, socket} ->
          spawn( fn -> broadcast_receive_and_connect(socket) end)
      end
    end


@doc """
@brief Helper function to broadcast_receive and connect to the node recived, will loop and should only be spawned by broadcast_listen
"""
  defp broadcast_receive_and_connect(socket)
    do
      case :gen_udp.recv(socket, 0) do
        {:ok, recv_packet} ->

          node_list = Kernel.elem(recv_packet, 2)
          node_atom = String.to_atom(to_string(node_list))

        if (node_atom != Node.self()) do
          SystemNode.connect_node_network(node_atom)
        end

        {:error, reason} ->
          Logger.error("Failed to receive due to #{reason}")
      end
      broadcast_receive_and_connect(socket) # While loop to keep the tread alive and alway listeninng for new connection
    end
end
