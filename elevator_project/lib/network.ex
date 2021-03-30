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
    :could_not_get_ip               If the IP-address could not be
                                      resolved
  """
  def get_ip(port \\ @init_port)
  when port - @init_port < 10
  do
    {:ok, socket} = :gen_udp.open(port, [active: false, broadcast: true])
    :gen_udp.send(socket, @broadcast_address, port, "Getting ip")

    ip =
    case :gen_udp.recv(socket, 0, 100) do
      {:ok, {ip, _port, _data}} ->
        ip
      {:error, _reason} ->
        get_ip(port + 1)
    end

    :gen_udp.close(socket)
    ip
  end

  def get_ip(_port)
  do
    IO.puts("Couldn't get local ip-address")
    :could_not_get_ip
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
