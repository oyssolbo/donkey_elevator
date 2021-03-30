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
    case :gen_udp.recv(socket, 100, 1000) do
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


  @doc """
  Init the node nettork on the machine
  """
  def node_network_init()
  do
    node_name = Kernel.inspect(:rand.uniform(10000))
    node_name_ip_s = node_name <> "@" <> get_ip()
    node_name_ip_a = String.to_atom(node_name_ip_s)
    SystemNode.start_node(node_name_ip_a)

    UDP_discover.broadcast_listen() #listen for other nodes forever
    spawn( fn -> UDP_discover.broadcast_cast(node_name_ip_s)) #cast node names forever

  end

  def send_data_to_all_nodes(sender_id, receiver_id,data, iteration \\ 0)
  do
    message_id = 0; # replace with get utc time now
    network_list = SystemNode.nodes_in_network()
    {node, network_list} = List.pop_at(network_list, iteration)
    if node != :nil do
      send({receiver_id, node}, {sender_id, {message_id, data}})
      send_data_to_all_nodes(sender_id, receiver_id, data, iteration + 1)
    end
  end

  def send_data_inside_node(sender_id, receiver_id, data)
  do
    message_id = 0; # replace with get UTC time now
    send({receiver_id, Node.self()}, {sender_id, {message_id, data}})
  end

  def receive_thread(sender_id, handler)
  do
    receive do
      {:master, {message_id, data}} -> IO.puts("Got the following data from master #{data}")
      {:panel, {message_id, data}} -> IO.puts("Got the following data from master #{data}")

    #after
    #  10_000 -> IO.puts("Connection timeout")

    end
  end
end
