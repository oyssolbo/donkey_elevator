defmodule Master do
  @moduledoc """
  Module implementing the master-module. The model is a combined process-pair between
  an active and a backup process. The master is initialized as backup, however if a
  timeout occurs without any heartbeats from active master, it is activated. If for
  some reason, there are two active masters available, the master which was
  activated first is considered active. Since we cannot know which are most valid
  (in case of a network-error), the orders are OR-ed in.

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

  @update_active_time         Application.fetch_env!(:elevator_project, :master_update_active_time_ms)
  @update_lights_time         Application.fetch_env!(:elevator_project, :master_update_lights_time_ms)
  @timeout_active_master_time Application.fetch_env!(:elevator_project, :master_timeout_active_ms)
  @timeout_elevator_time      Application.fetch_env!(:elevator_project, :master_timeout_elevator_ms)

  @max_resends                Application.fetch_env!(:elevator_project, :network_resend_max_counter)

  @node_name                  :master

  @enforce_keys [
    :order_list,
    :master_timer,            # Time of last connection with active master
    :master_message_id,       # ID of last message received from active_master
    :activation_time,         # Time the master became active
    :connected_elevators      # List of connection-id the master has with each elevator
  ]

  defstruct [:order_list, :master_timer, :master_message_id, :activation_time, :connected_elevators]


###################################### External functions ######################################

##### GenStateMachine-server #####


  @doc """
  Function to initialize the master, and transitions the master into backup_state
  The function establishes connection to GenStateMachine-server and initializes the
  data on the server
  """
  def init([])
  do
    Logger.info("Master initialing")

    data = %Master{
      order_list:        [],
      master_timer:             make_ref(),
      master_message_id:        0,
      activation_time:          :nil,
      connected_elevators:     []
    }

    master_data = Timer.start_timer(self(), data, :master_timer, :master_active_timeout, @timeout_active_master_time)

    case Process.whereis(:master_receive) do
      :nil->
        Logger.info("Starting receive-process for master")
        init_receive()
      _->
        Logger.warning("Receive-process for master already active")
    end

    Logger.info("Master initialized")

    {:ok, :backup_state, master_data}
  end


  @doc """
  Starting link to GenStateMachine-server
  """
  def start_link(init_arg \\ [])
  do
    server_opts = [name: @node_name]
    GenStateMachine.start_link(__MODULE__, init_arg, server_opts)
  end


  @doc """
  Terminates the master in case of an emergency
  """
  def terminate(_reason, _state)
  do
    Logger.info("Master given order to terminate. Terminating")
    Process.exit(self(), :normal)
  end


##### Networking and interface to external modules #####

  @doc """
  Receives messages from elevator, panel or other master. The function casts a message
  to the GenStateMachine-server, such that all events can be handled properly. The module
  is operating with multiple receive-threads, and the events are written out to separate
  the events between the receive-functions. Otherwise - if a general {event_name, data}
  is used, it would allow {message_id, :ack} to interfere. Secondly, it gives greater
  freedom to design the interactions better
  """
  defp receive_thread()
  do
    receive do
      {:master, _from_node, _message_id, {event_name, data}} ->
        GenStateMachine.cast(@node_name, {event_name, data})

      {:elevator, from_node, _message_id, :elevator_init} ->
        GenStateMachine.cast(@node_name, {:elevator_init, from_node})

      {:elevator, from_node, message_id, {:elevator_served_order, served_order_list, ack_pid}} ->
        Logger.info("Master received message that elevator has served order(s)")
        Network.send_data_spesific_node(:master, ack_pid, from_node, {message_id, :ack})
        GenStateMachine.cast(@node_name, {:elevator_served_order, from_node, served_order_list})


      {:elevator, from_node, _message_id, {:elevator_status_update, {last_dir, last_floor}}} ->
        GenStateMachine.cast(@node_name, {:elevator_status_update, from_node, {last_dir, last_floor}})

      {:panel, from_node, message_id, order_list} ->
        GenStateMachine.cast(@node_name, {:panel_received_order, order_list})
        Network.send_data_spesific_node(:master, :panel, from_node, {message_id, :ack})
    end

    receive_thread()
  end

  defp init_receive()
  do

    spawn_link(fn -> receive_thread() end) |>
      Process.register(:master_receive)
  end



  @doc """
  Sends a list of orders to an elevator. Continues to try until it receives an ack or a certain amount of
  time has passed. If no response from elevator, it is removed from the list. Conter and ack_pid should be left blank.
  """
  defp send_order_to_elevator(
        order_list,
        elevator_id,
        counter \\ 0,
        ack_pid \\ make_ref())
  when counter < @max_resends
  do
    ack_pid = ack_pid |> Kernel.inspect() |> String.to_atom()

    if(counter == 0) do
      Process.register(self, ack_pid)
    end

    Logger.info("Master sending orders to elevator #{elevator_id}")
    message_id  = Network.send_data_spesific_node(:master, :elevator_receive, elevator_id, {:delegated_order, order_list, ack_pid})

    case Network.receive_ack(message_id) do
      {:ok, _receiver_id} ->
        :ok
      {:no_ack, :no_id} ->
        send_order_to_elevator(order_list, elevator_id, counter + 1, ack_pid)
    end
  end

  defp send_order_to_elevator(
        _order_list,
        elevator_id,
        counter,
        _ack_pid)
  when counter == @max_resends
  do
    Logger.info("Master is unable to send order to elevator")

    # We can assume that the elevator has received a timeout
    GenStateMachine.cast(@node_name, {:elevator_timeout, elevator_id})
  end


  @doc """
  Sends (read: spams) data to other master
  """
  defp send_data_to_master(%Master{} = master_data)
  do
    Network.send_data_all_other_nodes(:master, :master_receive, {:master_update_active, master_data})
  end


  @doc """
  Broadcasts the lights that should be set or cleared
  """
  defp broadcast_hall_lights(external_order_list)
  when external_order_list |> is_list()
  do
    Network.send_data_all_nodes(:master, :lights_receive, {:set_hall_lights, external_order_list})
  end


###################################### Events and transitions ######################################


##### backup_state #####

  @doc """
  Function to handle if the backup-master has not received any updates from the active master
  within the timeout. Activates the master and transitions into active
  """
  def handle_event(
        :info,
        :master_active_timeout,
        :backup_state,
        master_data)
  do
    Logger.info("Backup has lost connection to active. Activating")

    Timer.interrupt_after(self(), :master_update_master_timer, @update_active_time)
    Timer.interrupt_after(self(), :master_update_lights_timer, @update_lights_time)

    activated_master_data =
      Timer.set_utc_time(master_data, :activation_time) |>
      Map.put(:master_message_id, 0)
    {:next_state, :active_state, activated_master_data}
  end


  @doc """
  Function to handle if data has been sent from the active-master to the passive master
  The heartsbeats / messages are only considered valid if the message-id exceeds the
  previous message-id
  """
  def handle_event(
        :cast,
        {:master_update_active, extern_master_data},
        :backup_state,
        intern_master_data)
  do
    extern_message_id = Map.get(extern_master_data, :master_message_id, 0)
    intern_message_id = Map.get(intern_master_data, :master_message_id, 0)

    new_master_data =
      cond do
        intern_message_id < extern_message_id ->
          order_list = Map.get(extern_master_data, :order_list)
          connected_elevators =    Map.get(extern_master_data, :connected_elevators)

          Timer.start_timer(self(), intern_master_data, :master_timer, :master_active_timeout, @timeout_active_master_time) |>
            Map.put(:order_list, order_list) |>
            Map.put(:connected_elevators, connected_elevators)    |>
            Map.put(:master_message_id, extern_message_id)

        intern_message_id >= extern_message_id ->
          intern_master_data
      end

    {:next_state, :backup_state, new_master_data}
  end


  @doc """
  Function to handle if the GenStateMachine-server received other messages while in :backup_state.

  These messages are considered not important, and results in no change of operation / state for the
  backup-master. The messages / message-types are:
    - :master_update_master_timer
    - :master_update_lights_timer
    - :elevator_status_update
    - :elevator_served_order
    - :elevator_timeout or :elevator_init
    - :panel_received_order

  It is assumed that active master will handle these events, and indirectly update backup-master
  """
  def handle_event(
        _,
        _,
        :backup_state,
        master_data)
  do
    {:next_state, :backup_state, master_data}
  end



##### active_state #####

  @doc """
  Updates the backup_master with the current system-state
  """
  def handle_event(
        :info,
        :master_update_master_timer,
        :active_state,
        master_data)
  do
    Timer.interrupt_after(self(), :master_update_master_timer, @update_active_time)

    updated_message_id = Map.get(master_data, :master_message_id) + 1
    new_master_data = Map.put(master_data, :master_message_id, updated_message_id)

    send_data_to_master(new_master_data)
    {:next_state, :active_state, new_master_data}
  end


  @doc """
  Handler event that triggers for broadcasting the external lights to all nodes in
  the network. By continously broadcasting the external orders, one guarantees that
  a network-error will not cause critical-future damage
  """
  def handle_event(
        :info,
        :master_update_lights_timer,
        :active_state,
        master_data)
  do
    Map.get(master_data, :order_list) |>
      Enum.filter(fn order -> order.order_type in [:hall_up, :hall_down] end) |>
      broadcast_hall_lights()

    Timer.interrupt_after(self(), :master_update_lights_timer, @update_lights_time)
    {:next_state, :active_state, master_data}
  end



  @doc """
  Handler event that triggers whenever there are two active master simultaneously. The
  function differentiates with 'internal_master_data' and 'external_master_data'. Since
  both of these could have valid data, they are combined to 'combined_master_data'. The
  orders are OR-ed, while all of timers are reset. The state is determined on the times
  of activation; the oldest master is kept active, while the youngest is set to backup.
  If both have the same time - unlikely as it is - both are set to sleep for a random
  amount of time, before being set as backup.
  """
  def handle_event(
        :cast,
        {:master_update_active, extern_master_data},
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
          reset_timer_master_data = Timer.start_timer(self(), combined_master_data, :master_timer, :master_active_timeout, @timeout_active_master_time)
          :rand.uniform(200) |>
            Process.sleep()
          {:backup_state, reset_timer_master_data}
        :gt->
          Logger.info("Transition into backup state")
          reset_timer_master_data = Timer.start_timer(self(), combined_master_data, :master_timer, :master_active_timeout, @timeout_active_master_time)
          {:backup_state, reset_timer_master_data}
      end

    {:next_state, next_state, new_master_data}
  end


  @doc """
  Function to handle when an elevator sends a status-update to the master.
  """
  def handle_event(
        :cast,
        {:elevator_status_update, elevator_id, {dir, last_floor}},
        :active_state,
        master_data)
  do
    # Add to list of connected elevators and reset timer
    old_elevator_client_list = Map.get(master_data, :connected_elevators)
        elevator_client =
      case Client.extract_client(elevator_id, old_elevator_client_list) do
        [] ->
          struct(Client,
            [
              client_id: elevator_id,
              client_data: %{dir: dir, last_floor: last_floor},
              client_timer: make_ref()
            ])
        [old_client] ->
          Client.modify_client_field(old_client, :client_data, %{dir: dir, last_floor: last_floor})
      end

    updated_elevator_list =
      Timer.start_timer(self(), elevator_client, :client_timer, {:elevator_timeout, elevator_id}, @timeout_elevator_time) |>
      Client.add_clients(old_elevator_client_list)

    # Delegate any undelegated orders
    order_list = Map.get(master_data, :order_list)

    undelegated_orders = get_undelegated_orders(master_data)

    other_orders =
      undelegated_orders |>
      Order.remove_orders(order_list)

    delegated_orders = delegate_orders(undelegated_orders, updated_elevator_list)

    # Since we have connection to at least one elevator, we can assume that all orders are delegated
    new_order_list = Order.add_orders(delegated_orders, other_orders)
    new_master_data =
      Map.put(master_data, :connected_elevators, updated_elevator_list) |>
      Map.put(:order_list, new_order_list)

    {:next_state, :active_state, new_master_data}
  end


  @doc """
  Function that handles if an elevator sends an important status-message; that it has
  served order(s). The order(s) can then be removed from the list, and the lights can
  be reset
  """
  def handle_event(
        :cast,
        {:elevator_served_order, _elevator_id, served_order_list},
        :active_state,
        master_data)
  do
    Logger.info("Inside handler-event in master that elevator has served an order")

    order_list = Map.get(master_data, :order_list)
    updated_order_list = Order.remove_orders(served_order_list, order_list)

    new_master_data = Map.put(master_data, :order_list, updated_order_list)
    {:next_state, :active_state, new_master_data}
  end


  @doc """
  Function to handle if an elevator gets a timeout / is disconnected / is inited.
  The function detects which external orders are affected, and
  redelegates them to the other elevators.
  If there are no connected elevators, the orders' delegated field are set to :nil.
  When one elevator becomes active again, it will receive all orders with field set
  to :nil - rip that elevator (and those people waiting...)
  """
  def handle_event(
        _,
        {emergency_atom, elevator_id},
        :active_state,
        master_data)
  when emergency_atom in [:elevator_timeout, :elevator_init]
  do
    # Find and remove the connection
    elevator_list = Map.get(master_data, :connected_elevators)
        updated_elevator_list =
      Client.extract_client(elevator_id, elevator_list) |>
      Client.remove_clients(elevator_list)

    # Find a list of affected orders and unaffected orders
    order_list = Map.get(master_data, :order_list)
    affected_orders = Order.extract_orders(elevator_id, order_list)
    unaffected_orders = Order.remove_orders(affected_orders, order_list)

    # Distribute these orders to the other elevators
    delegated_orders = delegate_orders(affected_orders, updated_elevator_list)

    # Combining the two sets of orders, and adding to master_data
    new_order_list = Order.add_orders(delegated_orders, unaffected_orders)
    new_master_data = Map.put(master_data, :order_list, new_order_list)

    {:next_state, :active_state, new_master_data}
  end


  @doc """
  Handle if the GenStateMachine-server receives a list of orders from panel
  """
  def handle_event(
        :cast,
        {:panel_received_order, order_list},
        :active_state,
        master_data)
  when order_list |> is_list() and order_list != []
  do
    new_master_data =
      case Order.check_valid_order(order_list) do
        :true->
          temp_order_list = Order.modify_order_field(order_list, :delegated_elevator, :nil)
          undelegated_orders = get_undelegated_orders(master_data, temp_order_list)

          connected_elevators =    Map.get(master_data, :connected_elevators)
              delegated_orders = delegate_orders(undelegated_orders, connected_elevators)

          updated_order_list =
            Map.get(master_data, :order_list) |>
            Order.add_orders(delegated_orders)

          Map.put(master_data, :order_list, updated_order_list)

        :false->
          master_data
      end

    {:next_state, :active_state, new_master_data}
  end


   @doc """
  Function to handle if the GenStateMachine-server receives an unexpected event
  """
  def handle_event(
        _,
        _,
        state,
        master_data)
  do
    {:next_state, state, master_data}
  end


###################################### Actions ######################################


  @doc """
  Function that merges two master_data-structs into one single master-data-struct
  Since we cannot know which master-data struct contains the most correct information,
  the orders are OR-ed together, with the field :delegated_order set to :nil. The
  information about the elevators are discarded, since it is updated continously.
  It will not be as efficient, as one elevator may become overloaded with work
  """
  defp combine_master_data_struct(
        intern_master_data,
        extern_master_data)
  do
    intern_orders = Map.get(intern_master_data, :order_list)
    extern_orders = Map.get(extern_master_data, :order_list)

    intern_connected_elevators = Map.get(intern_master_data, :connected_elevators)
        extern_connected_elevators = Map.get(extern_master_data, :connected_elevators)

    intern_message_id = Map.get(intern_master_data, :master_message_id, 0)
    extern_message_id = Map.get(extern_master_data, :master_message_id, 0)

    # Set all orders to be unassigned (:nil)
    intern_undelegated_orders = unassign_all_orders(intern_orders)
    extern_undelegated_orders = unassign_all_orders(extern_orders)

    new_order_list = Order.add_orders(intern_undelegated_orders, extern_undelegated_orders)

    # Cancel all timers, and remove info about the elevators from the list
    Client.cancel_all_client_timers(intern_connected_elevators)
    Client.cancel_all_client_timers(extern_connected_elevators)

    new_elevator_connection_list = []

    # Set message id and update intern_master_data
    new_message_id = max(intern_message_id, extern_message_id)

    Map.put(intern_master_data, :order_list, new_order_list) |>
      Map.put(:master_message_id, new_message_id) |>
      Map.put(:connected_elevators, new_elevator_connection_list)
  end


  @doc """
  Unassigns all orders. In other words, it sets the delegated elevator to :nil for all
  orders in the list.
  Returns a list of the new-undelegated orders
  """
  defp unassign_all_orders([order | rest_orders])
  do
    updated_order = Order.modify_order_field(order, :delegated_elevator, :nil)
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
        [] = _connected_elevators)
  do
    Order.modify_order_field(orders, :delegated_elevator, :nil)
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
    delegated_order = Order.modify_order_field(order, :delegated_elevator, optimal_elevator_id)
    spawn_link(fn-> send_order_to_elevator([delegated_order], optimal_elevator_id) end)


    [delegated_order | delegate_orders(rest_orders, connected_elevators)]
  end

  defp delegate_orders(
        [],
        _connected_elevators)
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
    old_order_list = Map.get(master_data, :order_list, [])

    old_nil_delegated_orders = Order.extract_orders(:nil, old_order_list)
    new_nil_delegated_orders = Order.extract_orders(:nil, new_order_list)

    Order.add_orders(old_nil_delegated_orders, new_nil_delegated_orders)
  end


## Determine elevator ##
  @doc """
  Function that finds the optimal elevator to serve an order.
  The function uses previous information, which means the optimal elevator can
  be the worst elevator to perform the order. It is assumed that there are enough
  elevators and not enough floors to be relevant. For a larger building, a better
  function must be developed
  """
  defp find_optimal_elevator(
        order,
        [check_elevator | rest_elevator],
        optimal_elevator)
  do
    optimal_data = Map.get(optimal_elevator, :client_data)

    if optimal_data == :nil do
      find_optimal_elevator(order, rest_elevator, check_elevator)

    else
      cost_optimal_elevator = calculate_elevator_cost(order, optimal_elevator)
      cost_check_elevator = calculate_elevator_cost(order, check_elevator)

      if cost_optimal_elevator <= cost_check_elevator do
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
    optimal_elevator
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
    elevator_data = Map.get(elevator, :client_data)
    elevator_data_dir = Map.get(elevator_data, :dir)
    elevator_data_floor = Map.get(elevator_data, :last_floor)

    order_type = Map.get(order, :order_type)
    order_floor = Map.get(order, :order_floor)

    elevator_in_dir = check_elevator_in_dir?(elevator_data_dir, elevator_data_floor, order_type, order_floor)

    if elevator_in_dir do
      abs(order_floor - elevator_data_floor)
    else
      # Adding 1 such that elevator on floor but in wrong direction not prioritized
      1000 * (1 + abs(order_floor - elevator_data_floor))
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
end
