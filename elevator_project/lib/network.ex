defmodule Network do
  @moduledoc """
  Module for casting and receiving nodenames via UDP broadcast

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
    node_name_s = Kernel.inspect(:rand.uniform(10000)) <> "@" <> UDP_discover.get_ip()
    node_name_a = String.to_atom(node_name_s)
    SystemNode.start_node(node_name_a)
    UDP_discover.broadcast_listen() #listen for other nodes forever
    UDP_discover.broadcast_cast(node_name_s) #cast node names forever
  end

  @doc """
  Send data to all known nodes on the network to the process receiver_id
  """
  def send_data_to_all_nodes(sender_id, receiver_id,data, iteration \\ 0)
  do
    message_id = Timer.get_utc_time()
    network_list = SystemNode.nodes_in_network()
    {node, network_list} = List.pop_at(network_list, iteration)
    if node != :nil do
      send({receiver_id, node}, {sender_id, {message_id, data}})
      send_data_to_all_nodes(sender_id, receiver_id, data, iteration + 1)
    end
  end

  @doc """
  Send data locally (on the same node) to the process receiver_id
  """
  def send_data_inside_node(sender_id, receiver_id, data)
  do
    message_id = Timer.get_utc_time()
    send({receiver_id, Node.self()}, {sender_id, {message_id, data}})
  end


   @doc """
  Prof of concept function to demonstrate receive_functionallity
  """
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