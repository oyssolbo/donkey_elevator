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

  @min_floor              Application.fetch_env!(:elevator_project, :min_floor)
  @max_floor              Application.fetch_env!(:elevator_project, :num_floors) + @min_floor - 1
  @num_elevators          Application.fetch_env!(:elevator_project, :num_elevators)
  @cookie                 Application.fetch_env!(:elevator_project, :default_cookie)

  @default_check_time_ms  2000

  @node_name :master
  @enforce_keys [
    :active_orders,
    :connected_externals,
    :node_timers,
    :activation_time,
    :pid,
    :masterID,
    :versID
  ]

  defstruct [
    :active_orders,
    :connected_externals,
    :node_timers,
    :activation_time,
    :pid,
    :masterID,
    :versID
  ]


  @doc """
  Function to initialize the master-module

  The function sets the struct with the current active orders,
  connected external modules, timer for external nodes and the activation-time¨
  of the module
  """
  def init() do
    # Set correct master-state
    master_data = %Master{
      active_orders: :nil,
      connected_externals: :nil,
      node_timers: :nil,
      activation_time: Time.utc_now(),
      pid: :nil,
      masterID: :nil, # Could pherhaps just use name?
      versID: 0
    }

    # Start link to GenStateMachine
    start_link({:init_state, master_data})

    # Must include a way to init master node and throw error if true
    name = to_string(@node_name) <> to_string(Master[:activation_time])
    case SystemNode.start_node(name, @default_cookie) do
      pid ->
        # Successful in starting a distributed node
        # Inserting the correct pid
        Map.replace!(master_data, :pid, pid)

        # Connecting to other nodes
        SystemNode.connect_nodes(pid)

        # Spawning a function to detect
        spawn(fn-> check_external_nodes() end)

        # Changing state
        GenStateMachine.cast(@node_name, {:read_memory, master_data})

      {:error, _} ->
        # Not successful in starting a distributed node
        Logger.error("An error occured when trying to make master a distributed system. Restarting master")
        GenStateMachine.cast(@node_name, :restart)
    end
  end


  @doc """
  Function for terminating the server
  """
  def terminate(_reason, _state) do
    Logger.info("Master given orders to terminate. Terminating")
    Process.exit(self(), :normal)
  end

  ############################################### Events ################################################


  @doc """
  Function to link to the GenStateMachine-server
  """
  def start_link(init_arg \\ [:init_state]) do
    server_opts = [name: @node_name]
    GenStateMachine.start_link(__MODULE__, init_arg, server_opts)
  end


  @doc """
  Function to read the existing data in the memory, such that the server is up
  to date and can take descisions
  """
  def handle_event(:cast, {:read_memory, _}, :init_state, master_data) do
    # Must read from the Storage in some way, but unsure how

    # And which state should we transfer into?
    {:next_state, :backup_state, master_data}
  end

  @doc """
  Function to handle if restart being casted
  """
  def handle_event(:cast, :restart, _, _) do
    restart_process()
  end

  @doc """
  Function to handle if another master is active at the same time
  """
  def handle_event(:cast, {:another_active_server, t_other}, :active_state, master_data) do
    time = Map.get(master_data, :activation_time, Time.utc_now())
    case Time.compare(time, t_other) do
      :gt->
        # "Youngest" server. Step down
        acceptance_test()
        {:next_state, :backup_state, master_data}
      :eq->
        # Equivalent. Restart server - but must guarantee that everything ok first
        acceptance_test()
        GenStateMachine.cast(@node_name, :restart)
      :lt->
        # "Oldest" server. Continue
        {:next_state, :active_state, master_data}
    end
  end



  ############################################## Actions #################################################

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
        GenStateMachine.cast(@node_name, :restart)
    end
  end

  @doc """
  Function to terminate the process
  """
  defp restart_process() do
    Process.exit(self(), :normal)
  end

  @doc """
  Function to perform the acceptance-tests - must be developed
  """
  defp acceptance_test() do
    :ok
  end

end
