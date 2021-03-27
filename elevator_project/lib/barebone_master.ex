defmodule Master do
  @moduledoc """
  Barebone master-module that must be developed further.

  Requirements:
    - Network
    - Order
    - Elevator
    - Panel
    - Timer

  Could be used:
    - Storage
  """

##### Module definitions #####

  use GenStateMachine

  require Logger

  require Network
  require Elevator
  require Order
  require Panel
  require Timer

  require Storage

  @min_floor          Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor          Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1
  @num_elevators      Application.fetch_env!(:elevator_project, :project_num_elevators)
  @cookie             Application.fetch_env!(:elevator_project, :project_cookie_name)

  @update_active_time Application.fetch_env!(:elevator_project, :master_update_active_time_ms)
  @timeout_active     Application.fetch_env!(:elevator_project, :master_timeout_active_ms)
  @timeout_elevator   Application.fetch_env!(:elevator_project, :master_timeout_elevator_ms)

  @node_name          :master

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
    master_data = Timer.start_timer(self(), data, :active_master_timeout, @timeout_active)
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

  @doc """
  Function to handle if data has been sent from the active-master to the passive master
  """
  def handle_event(
        :cast,
        {:update_active_master, update_id, active_order_list, connectionID_list},
        :backup_state,
        master_data)
  do
    # Store the info sent from the master
    # Must store the current orders given from the active
  end


##### active_state #####

  # Handle if received status-update from an elevator
  def handle_event(
        :cast,
        {:status_update, elevator_id, status},
        :active_state,
        master_data)
  do
    # Must update the information the master knows about said elevator
    # Must pherhaps have a timer such that one could id when one elevator has used
  end


  # Handle if received an external order
  def handle_event(
        :cast,
        {:received_order, order},
        :active_state,
        master_data)
  do
    # Check if the order is valid

    # Add to list of orders

    # Delegate the order to an elevator

    # Wait for return-ack from said elevator

    {:next_state, :active_state, master_data}
  end


  # Handle if two masters are active simultaneously
  def handle_event(
        :info,
        {:update_active_master, update_id, active_order_list, connectionID_list},
        :active_state,
        master_data)
  do
    # Somehow there are two active masters simultaneously

    # Use a logical OR to merge the orders - since we don't want any orders being lost

    # Update the connectionID-list

    # Check which master was activated first. If activated first, resume master. If not become backup
    # If both activated at the same time, use a magic algorithm to demote one
  end


  # Handle if an elevator is inited (reset)
  def handle_event(
        {:call, from},
        {:elevator_init, elevator_id},
        :active_state,
        master_data)
  do
    # Check if there are any registered orders belonging to that elevator

    # Respond with a list of orders that elevator must serve
  end

##### all_states #####

  # Handle if no updates from an elevator within a certain time-frame
  # Both states could do this. It would allow the backup to already have the cost set
  # to infty if it becomes active
  def handle_event(
        :info,
        {:elevator_timeout, elevator_id},
        state,
        master_data)
  do
    # Set the cost of the given elevator to infty

    # Find a list of affected orders (that are not cab)

    # Distribute these orders to the other elevators

    {:next_state, state, master_data}
  end




###################################### Actions ######################################







end
