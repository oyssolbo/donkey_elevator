defmodule SystemNode do
  @moduledoc """
  Module for initializing, discovering and connecting all nodes on the network


  Dependencies:
    -GetIP
  """

  require Logger

  @default_tick_time 15000


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
        cookie)
  when cookie |> is_atom
  do
    # Accessing ip, starting node and setting cookie
    {:recv, ip} = Network.get_ip()
    name = name <> ip
    case Node.start(name, :longnames, @default_tick_time) do
      {:ok, pid} ->
        Node.set_cookie(pid, cookie)
        pid
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
    Logger.info("Node spawned")
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
  Connects the nodes on the network
  """
  def connect_nodes(node)
  do
    case Network.detect_nodes() do
      {:error, :node_not_running} ->
        Logger.error("No nodes available to connect")
        :ok
      {[head | tail]} ->
        Logger.info("Connecting to nodes")
        Node.connect(head)
    end
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

end
