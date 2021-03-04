defmodule SystemNode do
  @moduledoc """
  Module for initializing, discovering and connecting all nodes on the network


  Dependencies:
    -GetIP
  """

  require Logger

  @default_tick_time 500 #Interval between pings


  @doc """
  @brief            Initializing a node

  @param name       Start of the node's name. Concatinated with the node's IP-address
  @param cookie     The cookie of the network the node should listen to

  @retval       RETURNS:              IF:
                  :pid                  If started in distributed mode
                  self()                If not possible to start in distributed mode
  """
  def start_node(name, cookie) when cookie |> is_atom do
    # Accessing ip, starting node and setting cookie
    ip = Network.get_ip()
    name = name <> "@" <> ip
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
  @brief            Connecting a node to a function

  @param pid        Process ID of the node to be spawned
  @param module     The module of the corresponding @p function
  @param function   Given function the node should spawn
  @param args       The given parameters to the function
  @param opts       Given options for spawning

  @retval           Returns the PID (sadly not -controller) of the spawned function
  """
  def node_spawn_function(pid, module, function, args \\ [], opts \\ []) do
    # Spawning desired function
    pid = Node.spawn(pid, module, function, args, opts)
    Logger.info("Node spawned")
    pid
  end

  @doc """
  @brief        Closing a given node. The other nodes on the distributed system will
                  assume the node as down

  @warning      Requires the node to be started with Node.start/3. Otherwise returns
                  {:error, :not_allowed}

  @retval       RETURNS:                  IF:
                  :ok                       If allowed
                  {:error, :not_allowed}    If not allowed
                  {:error, :not_found}      If the node is dead
  """
  def close_node() do
    Node.stop()
    Logger.info("Node killed")
  end


  @doc """
  @brief        Connects the nodes on the network
  """
  def connect_nodes(node) do # should mby be renamed to discover nodes. Does not seem to actually connect to the node network
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
  @brief        Connects the node to node-network
  Just a sketch for now
  """
  def connect_node_network(node) do
    Node.ping(node)
  end


  @doc """
  @brief        Disconnect the node from the network

  @param node   Node to disconnect from the network

  @retval       RETURNS:                  IF:
                :true                       Disconnect succeded
                :false                      Disconnect fail
                :ignored                    Node not alive
  """
  def disconnect_node(node) do
    Node.disconnect(node)
    Logger.info("Node disconnected from the network")
  end

end
