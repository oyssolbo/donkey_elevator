defmodule Network do
  @moduledoc """
  Module giving basic functions for using networking

  Entire module inspired by Jostein Løwer

  Credit to: Jostein Løwer, NTNU (2019)
  Link: https://github.com/jostlowe/kokeplata/blob/master/lib/networkstuff.ex

  Dependencies:
  -UDP
  """

  require Logger

  @broadcast_address {255, 255, 255, 255}
  @init_port 6789
  @num_tries 5


  @doc """
  Function that hopefully returns the IP-address of the system

  port Port we should try to access. Default param set to @init_port

  RETURNS:                        IF:
    ip                              If the IP-address was found
    {:error, :could_not_get_ip}     If the IP-address could not be
                                      resolved
  """
  def get_ip(port \\ @init_port)
  do
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
  Formats an IP-address to a bytestring

  ip IP-address to convert to a bytestring
  """
  def ip_to_string(ip)
  do
    :inet.ntoa(ip) |> to_string()
  end



  @doc """
  Detects all nodes on the network

  RETURNS:                      IF:
    nodes                         If nodes discovered
    {:error, :node_not_running}   If no nodes discovered
  """
  def detect_nodes()
  do
    case [Node.self() | Node.list()] do
      [:'nonode@nohost'] ->
        {:error, :node_not_running}
      nodes ->
        nodes
    end
  end
end
