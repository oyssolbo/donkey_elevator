defmodule Master do
  @moduledoc """
  Module implementing the master-module

  This module must be responsible for interacting with all of the other modules

  Requirements:
    - Elevator
    - Network
    - Driver
    - Matriks
    - Panel (?)
    - Storage
  """

  use GenStateMachine

  require Logger
  require Driver
  require Network
  require Matriks
  require Panel
  require Storage
  require SystemNode
  require BareElevator

  @doc """
  The module must check if there are any other masters active during startup
  and then possibly change state accordingly

  If the other master is active as well, one must check which one has been
  active the longest


  Is it possible to use a struct to hold all of the desired data?
      E.G. Struct containing the current connected elevators and their respective
      orders and timers?
  """

  @min_floor 0
  @max_floor 3
  @num_elevators 1  # For the time being
  @default_cookie :ttk4145_30
  @default_check_time_ms 2000

  @node_name :master
  @enforce_keys [:active_orders, :connected_externals, :node_timers, :activation_time,
                  :pid, :masterID, :versID]

  defstruct [:active_orders, :connected_externals, :node_timers, :activation_time,
                  :pid, :masterID, :versID]


  @doc """
  Function to initialize the master-module

  The function sets the struct with the current active orders,
  connected external modules, timer for external nodes and the activation-time¨
  of the module
  """
  def init() do
    # Set correct elevator-state
    master_data = %Master{
      active_orders: :nil,
      connected_externals: :nil,
      node_timers: :nil,
      activation_time: make_ref(),
      pid: :nil, # Change this (?)
      masterID: :nil, # change this
      versID: :nil # and this
    }

    # Start link to GenStateMachine
    start_link({:init_state, master_data})

    # Must include a way to init master node and throw error if true
    name = to_string(@node_name) <> to_string(Master[:activation_time])
    case SystemNode.start_node(name, @default_cookie) do
      pid ->
        # Successfull in starting a distributed node
        # Connecting to other nodes
        SystemNodes.connect_nodes(pid)

        # Spawning a function to detect
        spawn(fn-> check_external_nodes() end)

        # Changing state
        GenStateMachine.cast({:read_memory, master_data})

      {:error, _} ->
        # Not successful in starting a distributed node
        Logger.error("An error occured when trying to make master a distributed system. Restarting master")
        GenStateMachine.cast(:restart)
    end
  end


  @doc """
  Function for terminating the server
  """
  def terminate(_reason, _state) do
    :error
  end


  @doc """
  Function to link to the GenStateMachine-server
  """
  def start_link(init_arg \\ [:init_state]) do
    server_opts = [name: @node_name]
    GenStateMachine.start_link(__MODULE__, init_arg, server_opts)
  end


  @doc """
  Function to check after other nodes on the network excluding one self
  """
  defp check_external_nodes() do
    # Wait for '@default_check_time_ms' before checking
    :timer.sleep(@default_check_time_ms)

    case Network.detect_nodes() do
      nodes ->
        check_external_nodes()
      {:error, _} ->
        Logger.info("No nodes detected. Master is restarting")
        GenStateMachine.cast(:restart)
    end
  end


  @doc """
  Function to read the existing data in the memory, such that the server is up
  to date and can take descisions
  """
  def handle_event(:cast, {:read_memory, master_data}) do
    # Must read from the Storage in some way, but unsure how

    # And which state should we transfer into?
    {:next_state, :backup_state, master_data}
  end

  @doc """

  """







end
