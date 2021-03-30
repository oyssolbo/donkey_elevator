defmodule SystemNode do
  @moduledoc """
  Module for initializing, discovering and connecting all nodes on the network


  Dependencies:
    -GetIP
  """

  #epmd -daemon if you get the error econ refused

  require Logger

  @default_tick_time 500 #Interval between pings (Testing needed to find optimum)
  @default_cookie :TTK4115

  @doc """
  Initializing a node

  name       Start of the node's name. Concatinated with the node's IP-address
  cookie     The cookie of the network the node should listen to

  RETURNS:              IF:
  :pid                  If started in distributed mode
  self()                If not possible to start in distributed mode
  """
  def start_node(
        name,
        cookie \\ @default_cookie)
  when cookie |> is_atom
  do
    case Node.start(name, :longnames, @default_tick_time) do
      {:ok, _pid} ->
        Node.set_cookie(Node.self(), cookie)
        Node.self()
      {:error, _} ->
        Logger.error("An error occured when starting the node #{name} as a distributed node")
        {:error, self()}
    end
  end


  @doc """
  Connecting a node to a function

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
    # Spawning desired function
    pid = Node.spawn(pid, module, function, args, opts)
    Logger.info("Link established")
    pid
  end




  def node_spawn_function_linked(pid, module, function, args \\ []) do
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

  RETURNS:                  IF:
  :ok                       If allowed
  {:error, :not_allowed}    If not allowed
  {:error, :not_found}      If the node is dead
  """
  def close_node()
  do
    Node.stop()
    Logger.info("Node killed")
  end


  @doc """
  Connects the nodes on the network, this is unfinished, Node.detect_nodes() does not seem to exist.
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
  def connect_node_network(node) do
    case Node.ping(node) do
    {:pong} ->
      Logger.info("Succesfully connected to #{node}")
    {:pang} ->
      Logger.info("Unable to conenct to #{node}")
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
  Disconnect the node from the network

  node   Node to disconnect from the network

  RETURNS:                  IF:
  :true                       Disconnect succeded
  :false                      Disconnect fail
  :ignored                    Node not alive
  """
  def disconnect_node(node)
  do
    Node.disconnect(node)
    Logger.info("Node disconnected from the network")
  end

  @doc """
  @brief Registrer the process as a atom on the following node
  """
  def register_process(id) when id |> is_atom()
  do
    Process.register(self(), id)
  end
end
