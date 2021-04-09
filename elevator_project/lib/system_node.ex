defmodule SystemNode do
  @moduledoc """
  Module for initializing, discovering and connecting all nodes on the network

  If the error "econnrefused" occurs, run epmd -daemon before iex

  Dependencies:
    -Network
  """

  require Logger

  @node_tick_time Application.fetch_env!(:elevator_project, :network_node_tick_time_ms)
  @node_cookie    Application.fetch_env!(:elevator_project, :project_cookie_name)

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
  Connecting a node to a spawned function

  pid        Process ID of the node to be spawned
  module     The module of the corresponding @p function
  function   Given function the node should spawn
  args       The given parameters to the function
  opts       Given options for spawning

  Returns the PID (sadly not -controller) of the spawned function
  """
  def node_spawn_function(
        pid,
        module,
        function,
        args \\ [],
        opts \\ [])
  do
    pid = Node.spawn(pid, module, function, args, opts)
    Logger.info("Link established")
    pid
  end


  def node_spawn_function_linked(
        pid,
        module,
        function,
        args \\ [])
  do
    # Spawning desired function as a process
    #pid = Node.spawn_link(node, module, fun, args)
    Logger.info("Link established")
    pid
  end



  @doc """
  Closing a given node. The other nodes on the distributed system will
  assume the node as down

  Requires the node to be started with Node.start/3. Otherwise returns
  {:error, :not_allowed}
  """
  def close_node()
  do
    Node.stop()
    Logger.info("Node killed")
  end


  @doc """
  Connects the nodes on the network, this is unfinished, Node.detect_nodes()
  does not seem to exist.
  """
  def connect_nodes(node)
  do
    case Node.detect_nodes() do
      {:error, :node_not_running} ->
        Logger.error("No nodes available to connect")
        :ok
      {[head | tail]} ->
        Logger.info("Connecting to nodes")
        Node.connect(head)
    end
  end

  @doc """
  @brief Connects the node to node-network
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
  @brief List all the current nodes, including the node the process is running on
  """
  def nodes_in_network()
  do
    Node.list([:visible, :this])
  end


  @doc """
  Disconnect the node 'node' from the network
  """
  def disconnect_node(node)
  do
    Node.disconnect(node)
    Logger.info("Node disconnected from the network")
  end


  @doc """
  Registrer the process as a atom on the following node
  """
  def register_process(id)
  when id |> is_atom()
  do
    Process.register(self(), id)
  end
end
