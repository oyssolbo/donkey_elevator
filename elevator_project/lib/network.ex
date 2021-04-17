defmodule Network do
  @moduledoc """
  Module for casting and receiving nodenames via UDP broadcast
  Dependencies:
  -UDP
  """

  require Logger

  @ack_timeout      Application.fetch_env!(:elevator_project, :network_ack_timeout_time_ms)
  @static_node_name Application.fetch_env!(:elevator_project, :node_name)
  @node_tick_time   Application.fetch_env!(:elevator_project, :network_node_tick_time_ms)
  @node_cookie      Application.fetch_env!(:elevator_project, :project_cookie_name)

  @doc """
  Init the node nettork on the machine
  Remember to run "epmd -daemon" in terminal (not in iex) befrore running program for the first time after a reboot
  Otherwise the error "econrefused" might apear and the network will not work
  """
  def init_node_network()
  do
    ip = UDP.get_ip()
    node_name_s = Kernel.inspect(:rand.uniform(10000)) <> "@" <> ip #use for testing where elevator/ node does not need to be restarted
    #node_name_s = @static_node_name <> "@" <> ip # use for testing where the elevator/node needs to be restarted, assures constant node_name
    node_name_a = String.to_atom(node_name_s)
    start_node(node_name_a)

    UDP.broadcast_listen() #listen for other nodes forever
    UDP.broadcast_cast(node_name_s) #cast node names forever

  end


  @doc """
  Initializing a node with name 'name' and cookie 'cookie'

  The function returns the :pid if it is started in distributed mode, or
  self() if unable to start in distirbuted mode
  """
  def start_node(
        name,
        cookie \\ @node_cookie)
  when cookie |> is_atom
  do
    case Node.start(name, :longnames, @node_tick_time) do
      {:ok, _pid} ->
        Node.set_cookie(Node.self(), cookie)
        Node.self()
      {:error, _} ->
        Logger.error("An error occured when starting the node #{name} as a distributed node")
        {:error, self()}
    end
  end

  @doc """
  Connects the node to node-network
  """
  def connect_node_network(node)
  do
    case Node.ping(node) do
      :pong ->
        Logger.info("Succesfully connected to #{node}")
      :pang ->
        Logger.info("Unable to connect to #{node}")
    end
  end

  @doc """
  List all the current nodes, including the node the process is running on
  """
  def nodes_in_network()
  do
    Node.list([:visible, :this])
  end


  @doc """
  Send data to all other known nodes  on the network to the process receiver_id, iteration should be left blank
  """
  def send_data_all_other_nodes(sender_id, receiver_id, data)
  when sender_id |> is_atom()
  and receiver_id |> is_atom()
  do
    message_id = make_ref()
    network_list = Node.list()

    send_data_all_nodes_loop(sender_id, receiver_id, data, network_list, message_id)

    message_id
  end


  @doc """
  Send data to all known nodes on the network (including itself) to the process receiver_id, iteration should be left blank
  """
  def send_data_all_nodes(sender_id, receiver_id, data)
  when sender_id |> is_atom()
  and receiver_id |> is_atom()
  do
    message_id = make_ref()
    network_list = nodes_in_network()

    send_data_all_nodes_loop(sender_id, receiver_id, data, network_list, message_id)

    message_id
  end


  @doc """
  heper function to send_data_all_nodes
  """
  defp send_data_all_nodes_loop(sender_id, receiver_id, data, network_list, message_id, iteration \\ 0)
  do
    receiver_node = Enum.at(network_list, iteration)

    if receiver_node not in [:nil] do
      send({receiver_id, receiver_node}, {sender_id, Node.self(), message_id, data})
      send_data_all_nodes_loop(sender_id, receiver_id, data, network_list, message_id, iteration + 1)
    end

  end

  @doc """
  Send data locally (on the same node) to the process receiver_id
  """
  def send_data_inside_node(sender_id, receiver_id, data)
  when sender_id |> is_atom()
  and receiver_id |> is_atom()
  do
    case Process.whereis(receiver_id) do
      :nil->
        Logger.error("Unable to send data because the process is not alive :)")
      _->
        message_id = make_ref()
        send(receiver_id, {sender_id, Node.self(), message_id, data})
    end
  end

  @doc """
  Send data to the spesific process "receiver_id" on the spesific node "receiver_node"
  """
  def send_data_spesific_node(sender_id, receiver_id, receiver_node, data)
  when sender_id |> is_atom()
  and receiver_id |> is_atom()
  and receiver_node |> is_atom()
  do
    message_id = make_ref()
    send({receiver_id, receiver_node}, {sender_id, Node.self(), message_id, data})
    message_id
  end


  @doc """
  Function that looks for acks with the message_id, message_id
  """
  def receive_ack(message_id)
  do
    receive do
      {receiver_id, _from_node, _ack_message_id, {message_id, :ack}} ->
        #Logger.info("Ack received")
        {:ok, receiver_id}
      after @ack_timeout ->
        Logger.info("Ack not received")
        {:no_ack, :no_id}
    end
  end

end
