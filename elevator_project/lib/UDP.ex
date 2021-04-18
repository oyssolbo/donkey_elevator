defmodule UDP do
  @moduledoc """
  Module granting basic functionality for networking, such as getting ip-address,
  broadcasting and listening
  """

  require Logger

  @default_ip_address {127, 0, 0, 1}
  @broadcast_address  {255, 255, 255, 255}
  @broadcast_port     9876
  @init_port          6789

  @num_tries          Application.fetch_env!(:elevator_project, :network_resend_max_counter)
  @broadcast_timeout  Application.fetch_env!(:elevator_project, :network_broadcast_timeout_ms)

  @doc """
  Function that hopefully returns the IP-address of the system. Returns
  a string containing the ip-address if found. Otherwise, it returns the
  ip-address of the local system
  """
  def get_ip(port \\ @init_port)
  do
    case :gen_udp.open(port, [active: false, broadcast: true]) do
      {:ok, socket} ->
        :gen_udp.send(socket, @broadcast_address, port, "test packet")

        ip = case :gen_udp.recv(socket, 100, 1000) do
          {:ok, {ip, _port, _data}} -> ip
          {:error, _} -> @default_ip_address
        end

        :gen_udp.close(socket)
        :inet.ntoa(ip) |>
          to_string()

      {:nil, _} ->
        if port - @init_port < @num_tries do
          get_ip(port + 1)
        else
          Logger.error("Could not find ip-address")
          :inet.ntoa(@default_ip_address) |>
            to_string()
        end
    end
  end


  @doc """
  Helper function to open UDP socket on the broadcast port with the broadcast options
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
  Function that will broadcast the node_name on the broadcast port
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
  Function that will broadcast the node_name on the broadcast port
  will loop in infinity
  """
  defp broadcast_cast_loop(node_name, socket, port)
  do
    :gen_udp.send(socket, @broadcast_address, port, node_name)
    Process.sleep(@broadcast_timeout)
    broadcast_cast_loop(node_name,socket, port)
  end


  @doc """
  Function that will receive node_name from the broadcast_cast function above, and
  connect to the node
  """
  def broadcast_listen(port \\ @broadcast_port)
  do
    case broadcast_open_socket(port) do
      {:ok, socket} ->
        spawn( fn -> broadcast_receive_and_connect(socket) end)
    end
  end


  @doc """
  Helper function to broadcast_receive and connect to the node recived, will loop and
  should only be spawned by broadcast_listen
  """
  defp broadcast_receive_and_connect(socket)
  do
    case :gen_udp.recv(socket, 0) do
      {:ok, recv_packet} ->
        node_atom =
          Kernel.elem(recv_packet, 2) |>
            to_string() |>
            String.to_atom()

      if (node_atom not in Network.nodes_in_network()) do
        Network.connect_node_network(node_atom)
      end

      {:error, reason} ->
        Logger.error("Failed to receive due to #{reason}")
    end
    broadcast_receive_and_connect(socket)
  end
end
