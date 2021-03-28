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
  @default_timeout 5000

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

  def broadcast_open_connection(port \\ @broadcast_port)
  do
    case UDP.open_connection(port, [active: false, broadcast: true, reuseaddr: :true]) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def broadcast_cast(node_name, port \\ @broadcast_port) do
    case broadcast_open_connection() do
      {:ok, socket} ->
        :gen_udp.send(socket, @broadcast_address, @broadcast_port, node_name)
      {:error, reason} ->
        Logger.error("The error #{reason} occured while trying to broadcast #{node_name}")
    end
  end

  def broadcast_listen(port \\ @broadcast_port)
    do
      case broadcast_open_connection() do
        {:ok, socket} ->
          spawn( fn -> broadcast_receive(socket) end)
      end
    end

    def broadcast_receive(socket)
    do
      case :gen_udp.recv(socket, 0, @default_timeout)  do
        {:ok, recv_packet} ->
          data = Kernel.elem(recv_packet, 2)
          Logger.info("Received the node #{data}")
          Node.ping(String.to_atom(Kernel.inspect(data)))
          {:recv, recv_packet}

        {:error, reason} ->
          Logger.error("Failed to receive due to #{reason}")
      end
    end
end
