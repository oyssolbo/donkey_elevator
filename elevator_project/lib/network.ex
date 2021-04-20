defmodule Network do
  @moduledoc """
  Module to set up and the network and provide easy tp use send functions
  Dependencies:
  -UDP
  """

  require Logger

  @ack_timeout      Application.fetch_env!(:elevator_project, :network_ack_timeout_time_ms)
  @static_node_name Application.fetch_env!(:elevator_project, :node_name)
  @node_tick_time   Application.fetch_env!(:elevator_project, :network_node_tick_time_ms)
  @node_cookie      Application.fetch_env!(:elevator_project, :project_cookie_name)

  @doc """
  Function to start a distributed elixir Node and reapeatedly broadcast the node name on the local network.
  The function will also connect to received node names
  -
  Remember to run "epmd -daemon" in terminal (not in iex) befrore running the program for the first time after a reboot.
  Otherwise the error "econrefused" might occur
  """
  def init_node_network()
  do
    ip = UDP.get_ip()
    node_name_s = get_random_node_name() <> "@" <> ip
    node_name_a = String.to_atom(node_name_s)
    start_node(node_name_a)

    UDP.broadcast_listen() #listen for other nodes forever
    UDP.broadcast_cast(node_name_s) #cast node name forever

  end


  @doc """
  Function to Initializie a Elixir distributed node
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
  Send data to all OTHER known nodes  on the network to the process receiver_id
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
  Send data to ALL known nodes on the network (including itself) to the process receiver_id
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
        {:no_ack, :no_id}
    end
  end

  @doc """
  Function to generate 5 random letter
  """
  def get_random_node_name()
  do
    Stream.repeatedly(fn -> Enum.random(65..90) end)
    |> Stream.uniq
    |> Enum.take(5)
    |> List.to_string()

  end

end
