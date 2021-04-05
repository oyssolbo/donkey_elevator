defmodule Network do
  @moduledoc """
  Module for casting and receiving nodenames via UDP broadcast

  Dependencies:
  -UDP
  """

  require Logger



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
  Remember to run "epmd -daemon" in terminal befrore running program for the first time
  """
  def init_node_network()
  do
    ip = UDP_discover.get_ip()
    node_name_s = Kernel.inspect(:rand.uniform(10000)) <> "@" <> ip
    node_name_a = String.to_atom(node_name_s)
    SystemNode.start_node(node_name_a)

    UDP_discover.broadcast_listen() #listen for other nodes forever
    UDP_discover.broadcast_cast(node_name_s) #cast node names forever

    #Not needed at the moment
    #id_table = :ets.new(:buckets_registry, [:set, :protected, :named_table])
    #:ets.insert(:buckets_registry, {Node.self(), make_ref()}) #Note, make_ref() can be swapped with ip if we know ip's will be unique
  end

  @doc """
  Send data to all known nodes on the network to the process receiver_id, iteration should be left blank
  """
  def send_data_to_all_nodes(sender_id, receiver_id,data, iteration \\ 0)
  do
    message_id = make_ref()

    network_list = SystemNode.nodes_in_network()
    receiver_node = Enum.at(network_list, iteration)

    if receiver_node != :nil do
      send({receiver_id, receiver_node}, {sender_id, Node.self(), message_id, data})
      send_data_to_all_nodes(sender_id, receiver_id, data, iteration + 1)
    end
    {:ok, network_list}
  end

  @doc """
  Send data locally (on the same node) to the process receiver_id
  """
  def send_data_inside_node(sender_id, receiver_id, data)
  do
    message_id = make_ref()

    send({receiver_id, Node.self()}, {sender_id, Node.self(), message_id, data})
  end

 @doc """
  Send data to the spesific process "receiver_id" on the spesific node "receiver_node"
  """
  def send_data_spesific_node(sender_id, receiver_id, receiver_node, data)
    do
      message_id = make_ref()
      send({receiver_id, receiver_node}, {sender_id, Node.self(), message_id, data})
    end

   @doc """
  Prof of concept function to demonstrate receive_functionallity
  """
  def receive_thread(sender_id, handler)
  do
    receive do
      {:master, sender_node, message_id, data} -> IO.puts("Got the following data from master #{data}")
      {:panel, message_id, data} -> IO.puts("Got the following data from panel #{data}")

    after
      10_000 -> IO.puts("Connection timeout")

    end
  end


 @doc """
  Returns the node id that is created in init_node_network
  kepts in case need arises
  """
  def get_node_id()
  do
    node_id_list = :ets.lookup(:buckets_registry, Node.self())
    [node_id_list_head | node_id_list_tail] = node_id_list
    {_node, node_id} = node_id_list_head
    node_id
  end
end
