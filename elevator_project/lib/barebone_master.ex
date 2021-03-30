defmodule Master do
  @moduledoc """
  Barebone master-module that must be developed further.

  Requirements:
    - Network
    - Order
    - Elevator
    - Panel
    - Timer
    - Client
  """

##### Module definitions #####

  use GenStateMachine

  require Logger

  require Network
  require Elevator
  require Order
  require Panel
  require Timer
  require Client

  @min_floor                  Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor                  Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1
  @num_elevators              Application.fetch_env!(:elevator_project, :project_num_elevators)
  @cookie                     Application.fetch_env!(:elevator_project, :project_cookie_name)

  @update_active_time         Application.fetch_env!(:elevator_project, :master_update_active_time_ms)
  @timeout_active_master_time Application.fetch_env!(:elevator_project, :master_timeout_active_ms)
  @timeout_elevator_time      Application.fetch_env!(:elevator_project, :master_timeout_elevator_ms)

  @node_name                  :master

  @enforce_keys [
    :active_order_list,
    :master_timer,            # Time of last connection with active master
    :master_message_id,       # ID of last message received from active_master
    :activation_time,         # Time the master became active
    :connected_elevator_list, # List of connection-id the master has with each elevator
    :master_id
  ]

  defstruct [
    :active_order_list,
    :master_timer,
    :master_message_id,
    :activation_time,
    :connected_elevator_list,
    :master_id
  ]

###################################### External functions ######################################

##### Client to GenStateMachine-server #####


  @doc """
  Function to initialize the master, and transitions the master into backup_state

  The function
    - establishes connection to GenStateMachine-server
    - stores the current data on the server
  """
  def init([])
  do
    Logger.info("Master initialing")

    # Set correct master data
    data = %Master{
      active_order_list:        [],
      master_timer:             make_ref(),
      master_message_id:        0,
      activation_time:          :nil,
      connected_elevator_list:  [],
      master_id:                Atom.to_string(@node_name) <> Network.get_ip()
    }

    # Starting process for error-handling
    master_data = Timer.start_timer(self(), data, :master_timer, :active_master_timeout, @timeout_active)

    Logger.info("Master initialized")

    {:ok, :backup_state, master_data}
  end


  @doc """
  Function to link to the GenStateMachine-server
  """
  def start_link(init_arg \\ [])
  do
    # Could potentially be a problem with using @node_name, as two servers
    # then will operate on the same name
    server_opts = [name: @node_name]
    GenStateMachine.start_link(__MODULE__, init_arg, server_opts)
  end


  @doc """
  Function to stop the elevator in case of the GenStateMachine-server crashes
  """
  def terminate(_reason, _state)
  do
    Logger.info("Master given order to terminate. Terminating")
    Process.exit(self(), :normal)
  end


##### Interface to external modules #####


  @doc """
  Function to send an order to an elevator

  Will continue to try until it receives an ack or a timeout is triggered
  """
  defp send_order_to_elevator(
        order,
        elevator_id,
        counter \\ 0)
  do
    pid = Process.whereis(elevator_id)
    # Process.send(pid, order)
  end

  @doc """
  Function for other modules to send order to the master
  """
  def get_orders()
  do
    # WIP
  end


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
    activated_master_data =
      Timer.set_utc_time(master_data, :activation_time) |>
      Map.put(:master_message_id, 0)
    {:next_state, :active_state, activated_master_data}
  end


  @doc """
  Function to handle if data has been sent from the active-master to the passive master

  The heartsbeats / messages are only considered valid if
  """
  def handle_event(
        :cast,
        {:update_active_master, extern_master_data},
        :backup_state,
        intern_master_data)
  do
    extern_message_id = Map.get(extern_master_data, :master_message_id, 0)
    intern_message_id = Map.get(intern_master_data, :master_message_id, 0)

    new_master_data =
      cond do
        intern_message_id < extern_message_id ->
          active_order_list = Map.get(extern_master_data, :active_order_list)
          connected_elevator_list = Map.get(extern_master_data, :connected_elevator_list)

          updated_timer_master_data = Timer.start_timer(self(), intern_master_data, :master_timer, :active_master_timeout, @timeout_active_master_time)
          updated_order_master_data = Map.put(updated_timer_master_data, :active_order_list, active_order_list)
          updated_connection_master_data = Map.put(updated_order_master_data, :connected_elevator_list, connected_elevator_list)
          Map.put(updated_connection_master_data, :master_message_id, extern_message_id)

        intern_message_id >= extern_message_id ->
          intern_master_data
      end
    {:next_state, :backup_state, new_master_data}
  end


  @doc """
  Function to handle if a timeout has occured for an elevator while the system is in
  backup-state. No action is performed here, as the backup does not care if this happens
  """
  def handle_event(
        :info,
        {:timeout_elevator, elevator_id},
        :backup_state,
        master_data)
  do
    {:next_state, :backup_state, master_data}
  end


  @doc """
  Function to handle if the GenStateMachine-server receives a request to spam status to the
  backup-master while the current state is in backup-state. This could occur if the current
  process was demoted from active to backup because two active master simultaneously
  """
  def handle_event(
        :info,
        :update_timer,
        :backup_state,
        master_data)
  do
    {:next_state, :backup_state, master_data}
  end


##### active_state #####

  @doc """
  Function to update the backup_master with the current system-state
  """
  def handle_event(
        :info,
        :update_timer,
        :active_state,
        master_data)
  do
    Timer.interrupt_after(self(), :update_timer, @update_active_time)

    # Update this when we know how to send data
    backup_master_pid = Process.whereis(:backup_master)

    updated_message_id = Map.get(master_data, :master_message_id) + 1

    if backup_master_pid != :nil do
      activation_time = Map.get(master_data, :activation_time)
      active_order_list = Map.get(master_data, :active_order_list)

      # Unsure if the backup-master really requires to know which elevators are connected or not
      connection_list = Map.get(master_data, :connected_elevator_list)
      Process.send(backup_master_pid, {self(), activation_time, updated_message_id, active_order_list, connection_list}, [])
    end

    new_master_data = Map.put(master_data, :master_message_id, updated_message_id)

    {:next_state, :active_state, new_master_data}
  end



  @doc """
  Function to handle if the GenStateMachine-server receives a list of orders

  Important that the function get a list of orders
  """
  def handle_event(
        :cast,
        {:received_order, order_list},
        :active_state,
        master_data)
  when order_list |> is_list()
  do
    # Check if valid, and delegate
    Order.check_valid_order_list(order_list)

    temp_order_list = Order.set_delegated_elevator(order_list, :nil)
    undelegated_orders = get_undelegated_orders(master_data, temp_order_list)

    connected_elevator_list = Map.get(master_data, :connected_elevator_list)
    delegated_orders = delegate_orders(undelegated_orders, connected_elevator_list)

    updated_order_list =
      Map.get(master_data, :active_order_list) |>
      Order.add_order(delegated_orders)

    new_master_data = Map.put(master_data, :active_order_list, updated_order_list)

    {:next_state, :active_state, new_master_data}
  end


  # Handle if two masters are active simultaneously
  def handle_event(
        :info,
        {:update_active_master, extern_master_data},
        :active_state,
        intern_master_data)
  do
    Logger.info("Two active masters simultaneously")

    intern_activation_time = Map.get(intern_master_data, :activation_time)
    extern_activation_time = Map.get(extern_master_data, :activation_time)

    combined_master_data = combine_master_data_struct(intern_master_data, extern_master_data)

    {next_state, new_master_data} =
      case Timer.compare_utc_time(intern_activation_time, extern_activation_time) do
        :lt->
          Logger.info("Maintaining active state")
          {:active_state, combined_master_data}
        :eq->
          Logger.info("Equal time detected. Transition into backup state")
          reset_timer_master_data = Timer.start_timer(self(), combined_master_data, :master_timer, :active_master_timeout, @timeout_active_master_time)
          {:backup_state, reset_timer_master_data}
        :gt->
          Logger.info("Transition into backup state")
          reset_timer_master_data = Timer.start_timer(self(), combined_master_data, :master_timer, :active_master_timeout, @timeout_active_master_time)
          {:backup_state, reset_timer_master_data}
      end

    {:next_state, next_state, new_master_data}
  end


  @doc """
  Function to handle when an elevator sends a status-update to the master.
  """
  def handle_event(
        :cast,
        {:status_update, {elevator_id, dir, last_floor}},
        :active_state,
        master_data)
  do
    # Add to list of connected elevators and reset timer
    old_elevator_client_list = Map.get(master_data, :connected_elevator_list)
    elevator_client =
      case Client.find_client(elevator_id, old_elevator_client_list) do
        [] ->
          struct(Client, [client_id: elevator_id, data: %{dir: dir, last_floor: last_floor}])
        old_client ->
          old_client
      end

    # Likely a bug here. We will not add the updated client to the client-list if it already exists...
    updated_elevator_list =
      Timer.start_timer(self(), elevator_client, :last_message_time, :elevator_timeout, @timeout_elevator_time) |>
      Client.add_client(old_elevator_client_list)

    # Delegate any undelegated orders
    order_list = Map.get(master_data, :active_order_list)

    undelegated_orders = get_undelegated_orders(master_data)

    other_orders =
      undelegated_orders |>
      Order.remove_orders(order_list)

    delegated_orders = delegate_orders(undelegated_orders, updated_elevator_list)

    # Since we have connection to at least one elevator, we can assume that all orders are delegated
    new_order_list = Order.add_order(delegated_orders, other_orders)
    new_master_data = Map.put(master_data, :active_orders, new_order_list)

    {:next_state, :active_state, new_master_data}
  end


  @doc """
  Function to handle if an elevator gets a timeout / is disconnected

  The function detects which external orders are affected by the disconnect, and
  redelegates them to the other elevators.

  If there are no connected elevators, the orders' delegated field are set to :nil.
  When one elevator becomes active again, it will receive all orders with field set
  to :nil
  """
  def handle_event(
        :info,
        {:elevator_timeout, elevator_id},
        :active_state,
        master_data)
  do
    # Find and remove the connection
    elevator_list = Map.get(master_data, :connected_elevator_list)
    updated_elevator_list =
      Client.find_client(elevator_id, elevator_list) |>
      Client.remove_client(elevator_list)

    # Find a list of affected orders and unaffected orders
    order_list = Map.get(master_data, :active_order_list)
    affected_orders = get_assigned_elevator_orders(order_list, elevator_id)
    unaffected_orders = Order.remove_orders(affected_orders, order_list)

    # Distribute these orders to the other elevators
    delegated_orders = delegate_orders(affected_orders, updated_elevator_list)

    # Combining the two sets of orders, and adding to master_data
    new_order_list = Order.add_order(delegated_orders, unaffected_orders)
    new_master_data = Map.put(master_data, :active_order_list, new_order_list)

    {:next_state, :active_state, new_master_data}
  end



###################################### Actions ######################################


  @doc """
  Function that merges two master_data-structs into one single master-data-struct

  Since we cannot know which master-data struct contains the most correct information,
  the orders are OR-ed together, with the field :delegated_order set to :nil. The
  information about the elevators are discarded, since that is the simplest. It is
  however possible to use the last-message time to find the updated value, however
  that could result in hasardious code. Instead all of the timers are canceled.

  It is assumed that the elevators spam out their information often enough, such that
  it should not be a problem. It will not be as efficient, as one elevator may become
  overloaded with work, but that is a consequence we are prepared to face
  """
  defp combine_master_data_struct(
        intern_master_data,
        extern_master_data)
  do
    intern_orders = Map.get(intern_master_data, :active_order_list)
    extern_orders = Map.get(extern_master_data, :active_order_list)

    intern_connected_elevators = Map.get(intern_master_data, :connected_elevator_list)
    extern_connected_elevators = Map.get(extern_master_data, :connected_elevator_list)

    intern_message_id = Map.get(intern_master_data, :master_message_id, 0)
    extern_message_id = Map.get(extern_master_data, :master_message_id, 0)

    # Set all orders to be unassigned (:nil)
    intern_undelegated_orders = unassign_all_orders(intern_orders)
    extern_undelegated_orders = unassign_all_orders(extern_orders)

    new_order_list = Order.add_order(intern_undelegated_orders, extern_undelegated_orders)

    # Cancel all timers, and remove info about the elevators from the list
    intern_elevators_canceled_timers = Client.cancel_all_client_timers(intern_connected_elevators)
    extern_elevators_canceled_timers = Client.cancel_all_client_timers(extern_connected_elevators)

    new_elevator_connection_list = []

    # Set message id and update intern_master_data
    new_message_id = max(intern_message_id, extern_message_id)

    Map.put(intern_master_data, :active_order_list, new_order_list) |>
      Map.put(:master_message_id, new_message_id) |>
      Map.put(:connected_elevator_list, new_elevator_connection_list)
  end


  @doc """
  Unassigns all orders. In other words, it sets the delegated elevator to :nil for all
  orders in the list.

  Returns a list of the new-undelegated orders
  """
  defp unassign_all_orders([order | rest_orders])
  do
    updated_order = Order.set_delegated_elevator(order, :nil)
    [updated_order | unassign_all_orders(rest_orders)]
  end

  defp unassign_all_orders([])
  do
    []
  end


  @doc """
  Function to delegate a set of orders to the optimal elevator(s).

  The function finds the optimal elevator to perform each order, and then delegates
  the order to said elevator.

  If no elevators are connected, all of the orders' attribute is set to :nil. Otherwise
  set to the delegated elevator.

  Returns a list of orders with the correct assigned elevator
  """
  defp delegate_orders(
        orders,
        [])
  do
    Order.set_delegated_elevator(orders, :nil)
  end

  defp delegate_orders(
        [order | rest_orders],
        connected_elevators)
  do
    # Determine which elevator is must suitable for a given order
    optimal_elevator_id =
      find_optimal_elevator(order, connected_elevators, struct(Client)) |>
      Map.get(:client_id)

    # Delegate the order to the optimal elevator
    delegated_order = Order.set_delegated_elevator(order, optimal_elevator_id)
    spawn(fn-> send_order_to_elevator(delegated_order, optimal_elevator_id) end)

    [delegated_order | delegate_orders(rest_orders, connected_elevators)]
  end

  defp delegate_orders(
        [],
        connected_elevators)
  do
    []
  end


  @doc """
  Function that gets a set of undelegated orders (orders with the field
  :delegated_elevator set to :nil). It can take in a new list of orders, and
  adds these orders to the list of undelegated orders
  """
  defp get_undelegated_orders(
        master_data,
        new_order_list \\ [])
  do
    old_orders = Map.get(master_data, :active_order_list)

    old_nil_delegated_orders = Order.get_orders_with_value(old_orders, :delegated_elevator, :nil)
    new_nil_delegated_orders = Order.get_orders_with_value(new_order_list, :delegated_elevator, :nil)

    Order.add_order(old_nil_delegated_orders, new_nil_delegated_orders)
  end


  @doc """
  Function that finds the optimal elevator to serve an order.

  The function uses previous information, which means the optimal elevator can
  be the worst elevator to perform the order. It is assumed that there are enough
  elevators and not enough floors to be relevant. For a larger building, a better
  function must be developed
  """
  defp find_optimal_elevator( # BUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUG
        order,
        [check_elevator | rest_elevator],
        optimal_elevator)
  do
    optimal_data = Map.get(optimal_elevator, :data)

    if optimal_data == :nil do
      find_optimal_elevator(order, rest_elevator, check_elevator)

    else
      cost_optimal_elevator = calculate_elevator_cost(order, optimal_elevator)
      cost_check_elevator = calculate_elevator_cost(order, check_elevator)

      if cost_optimal_elevator <= cost_elevator_elevator do
        find_optimal_elevator(order, rest_elevator, optimal_elevator)

      else
        find_optimal_elevator(order, rest_elevator, check_elevator)
      end
    end
  end

  defp find_optimal_elevator(
        _order,
        [],
        optimal_elevator)
  do
    optimal_elevator_id
  end



  @doc """
  Calculates the cost an elevator would have to an order.

  The function uses the difference between order_floor and elevator_floor, and
  multiplies by 1000 if the elevator must change direction
  """
  defp calculate_elevator_cost(
        order,
        elevator)
  do
    elevator_data = Map.get(elevator, :data)
    elevator_data_dir = Map.get(elevator_data, :dir)
    elevator_data_floor = Map.get(elevator_data, :last_floor)

    order_type = Map.get(order, :order_type)
    order_floor = Map.get(order, :order_floor)

    elevator_in_dir = check_elevator_in_dir?(elevator_data_dir, elevator_data_floor, order_type, order_floor)

    if elevator_in_dir do
      abs(order_floor - elevator_data_floor)
    else
      1000 * abs(order_floor - elevator_data_floor)
    end
  end


  @doc """
  Function that checks if an elevator moves towards an order or not.

  Ugly boolean logic
  """
  defp check_elevator_in_dir?(
        elevator_dir,
        elevator_floor,
        order_type,
        order_floor)
  do
    cond do
      elevator_dir == :down && order_floor > elevator_floor ->
        :false
      elevator_dir == :up && order_floor < elevator_floor ->
        :false
      elevator_dir != order_type && order_type != :cab ->
        :false
      elevator_dir == :down && order_type in [:down, :cab] && order_floor <= elevator_floor ->
        :true
      elevator_dir == :up && order_type in [:up, :cab] && order_floor >= elevator_floor ->
        :true
      :true ->
        # Any other case
        :false
    end
  end


  @doc """
  Function to get the orders previously assigned to a spesific elevator
  """
  defp get_assigned_elevator_orders(
        order_list,
        elevator_id)
  do
    Order.get_orders_with_value(order_list, :delegated_elevator, elevator_id)
  end

end
