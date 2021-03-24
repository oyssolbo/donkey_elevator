defmodule Master do
  @moduledoc """
  Barebone master-module that must be developed further.

  Requirements:
    - Network
    - Order
    - Elevator
    - Panel

  Could be used:
    - Storage
  """

##### Module definitions #####

  use GenStateMachine

  require Logger
  require Elevator
  require Network
  require Storage
  require Order

  @min_floor              Application.fetch_env!(:elevator_project, :min_floor)
  @max_floor              Application.fetch_env!(:elevator_project, :num_floors) + @min_floor - 1
  @num_elevators          Application.fetch_env!(:elevator_project, :num_elevators)
  @cookie                 Application.fetch_env!(:elevator_project, :default_cookie)

  @update_active_time     200  # ms - How often the active master should update the backup
  @timeout_active         4000 # ms - How long the backup will wait on active before becoming active

  @node_name :master

  @enforce_keys [
    :active_orders,
    :master_timer,      # Time of last connection with active master
    :activation_time,   # Time the master became active
    :connectionID_list  # List of connection-id the master has with each elevator
  ]

  defstruct [
    :active_orders,
    :master_timer,
    :activation_time,
    :connectionID_list
  ]

###################################### External functions ######################################

##### Connection to GenStateMachine-server #####


  @doc """
  Function to initialize the master, and transitions the master into backup_state

  The function
    - establishes connection to GenStateMachine-server
    - stores the current data on the server
    - spawns a process to continously check the state of the elevator
    - sets engine direction down
  """
  def init([])
  do
    Logger.info("Master initialized")

    # Set correct master data
    data = %Master{
      active_orders: [],
      master_timer: make_ref(),
      activation_time: :nil,
      connectionID_list: []
    }

    # Starting process for error-handling
    master_data = Timer.start_timer(self(), data, :active_master_timeout, @init_time)

    {:ok, :backup_state, master_data}
  end


  @doc """
  Function to link to the GenStateMachine-server
  """
  def start_link(init_arg \\ [])
  do
    server_opts = [name: @node_name]
    GenStateMachine.start_link(__MODULE__, init_arg, server_opts)
  end


  @doc """
  Function to stop the elevator in case of the GenStateMachine-server crashes
  """
  def terminate(_reason, _state)
  do
    Logger.info("Master given order to terminate. Terminating")
    Driver.set_motor_direction(:stop)
    Process.exit(self(), :normal)
  end


##### Interface to external modules #####


###################################### Events and transitions ######################################


##### backup_state #####

  @doc """
  Function to handle if the backup-master has not received any updates from the active master
  within the timeout. Activates the master and transitions into active
  """
  def handle_event(
        :info,
        :active_master_timeout,
        :backup_state,
        master_data)
  do
    activated_master_data = Timer.set_utc_time(master_data, :activation_time)

    {:next_state, :active_state, activated_master_data}
  end


##### active_state #####

  


##### all_states #####




###################################### Actions ######################################







end
