defmodule Network do
  @moduledoc """
  Module giving basic functions for using networking

  Entire module inspired by Jostein Løwer

  Credit to: Jostein Løwer, NTNU (2019)
  Link: https://github.com/jostlowe/kokeplata/blob/master/lib/networkstuff.ex
  """

  require Logger

  @broadcast_address {255, 255, 255, 255}
  @init_port 6789
  @num_tries 5


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
        UDP.send_data(socket, @broadcast_address, port, "Test")

        case UDP.receive_data(socket) do
          {:recv, {ip, _port, _data}} ->
            {:recv, ip}
          {:error, _} ->
            {:error, :could_not_get_ip}
        end

        UDP.close_socket(socket)

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
  @brief        Formats an IP-address to a bytestring

  @param ip     IP-address to convert to a bytestring
  """
  def ip_to_string(ip) do
    :inet.ntoa(ip) |> to_string()
  end



  @doc """
  @brief        Detects all nodes on the network

  @retval       RETURNS:                      IF:
                  nodes                         If nodes discovered
                  {:error, :node_not_running}   If nodes not running
  """
  def detect_nodes() do
    case [Node.self() | Node.list()] do
      [:'nonode@nohost'] ->
        {:error, :node_not_running}
      nodes ->
        nodes
    end
  end
end
