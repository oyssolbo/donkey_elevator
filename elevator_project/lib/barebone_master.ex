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

  @default_check_time_ms  2000 # ms

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
  Function to initialize the elevator, and tries to get the elevator into a defined state.

  The function
    - establishes connection to GenStateMachine-server
    - stores the current data on the server
    - spawns a process to continously check the state of the elevator
    - sets engine direction down
  """
  def init([])
  do
    # Logger.info("Elevator initialized")

    # # Set correct elevator-state
    # data = %Master{
    #   orders: [],
    #   last_floor: :nil,
    #   dir: :down,
    #   timer: make_ref()
    # }

    # # Close door and set direction down
    # close_door()
    # Driver.set_motor_direction(:down)

    # # Starting process for error-handling
    # elevator_data = Timer.start_timer(self(), data, :init_timer, @init_time)
    # spawn(fn-> read_current_floor() end)

    # {:ok, :init_state, elevator_data}
    {:ok, :init_state, []}
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

##### init_state #####


##### backup_state #####
  # Listen for updates from the active master (nothing else)


##### active_state #####
  # Listen and respond to all external messages
  # Must send data to the backup_state



##### all_states #####





  # States and what they should do
  # Active  -  Listen and respond to all external messages
  # Passive -  Listen for updates from the active master







end
