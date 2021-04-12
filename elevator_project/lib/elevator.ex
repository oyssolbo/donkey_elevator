
defmodule Elevator do
  @moduledoc """
  Module implementing the Elevator for the project
    States:               Transitions to:
      - :init_state         :idle_state, :restart_state
      - :idle_state         :moving_state
      - :moving_state       :door_state, :restart_state
      - :door_state         :idle_state
      - :restart_state      :restart_state

  Requirements:
    - Driver
    - Network
    - Order
    - Panel
    - Lights
    - Timer
    - Storage
  """

##### Module definitions #####

  use GenStateMachine

  require Logger

  require Driver
  require Network
  require Order
  require Panel
  require Lights
  require Timer
  require Storage

  @min_floor            Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor            Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1
  @cookie               Application.fetch_env!(:elevator_project, :project_cookie_name)

  @init_time            Application.fetch_env!(:elevator_project, :elevator_timeout_init_ms)
  @door_time            Application.fetch_env!(:elevator_project, :elevator_timeout_door_ms)
  @moving_time          Application.fetch_env!(:elevator_project, :elevator_timeout_moving_ms)
  @status_update_time   Application.fetch_env!(:elevator_project, :elevator_update_status_time_ms)

  @restart_time         Application.fetch_env!(:elevator_project, :elevator_restart_time_ms)

  @node_name            :elevator

  @enforce_keys         [:orders, :last_floor, :dir, :timer, :elevator_id]
  defstruct             [:orders, :last_floor, :dir, :timer, :elevator_id]


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
    Logger.info("Elevator initializing")

    # Set correct elevator-state
    data = %Elevator{
      orders:       [],
      last_floor:   :nil,
      dir:          :down,
      timer:        make_ref(),
      elevator_id:  Node.self()
    }

    # Messaging master that elevator is inited
    broadcast_elevator_init()

    # Close door and set direction down
    close_door()
    Driver.set_motor_direction(:down)

    # Starting process for error-handling
    elevator_data = Timer.start_timer(self(), data, :timer, :init_timer, @init_time)
    spawn_link(fn-> read_current_floor() end)

    case Process.whereis(:elevator_receive) do
      :nil->
        Logger.info("Starting receive-process for elevator")
        init_receive()
      _->
        Logger.info("Receive-process for elevator already active")
    end

    Logger.info("Elevator initialized")
    {:ok, :init_state, elevator_data}
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
    Logger.info("Elevator given order to terminate. Terminating")
    Driver.set_motor_direction(:stop)
    Process.exit(self(), :normal)
  end


##### Networking and interface to external modules #####

  @doc """
  Process for receiving data from master and panel, and calls the respective
  handlers in the GenStateMachine-server
  """
  defp receive_thread()
  do
    receive do
      {:master, _node, message_id, data} ->
        Logger.info("Elevator received order from master")
        Network.send_data_all_nodes(:elevator, :master, {message_id, :ack})
        GenStateMachine.cast(@node_name, {:received_order, data})

      {:panel, _node, message_id, data} ->
        Logger.info("Elevator received order from panel")
        IO.inspect(data)
        Network.send_data_inside_node(:elevator, :panel, {message_id, :ack})
        GenStateMachine.cast(@node_name, {:received_order, data})
    end

    receive_thread()
  end

  defp init_receive()
  do
    spawn_link(fn -> receive_thread() end) |>
      Process.register(:elevator_receive)
  end


  @doc """
  Functions for broadcasting different information to other nodes:

    broadcast_elevator_init: broadcasts to all nodes that the elevator is just initialized

    broadcast_served_orders: broadcasts a list of orders that the elevator has served

    broadcast_elevator_status: broadcast the status (dir, last_floor) to all other nodes
  """
  defp broadcast_elevator_init()
  do
    spawn_link(fn -> Network.send_data_all_nodes(:elevator, :master, :elevator_init) end)
  end


  defp broadcast_served_orders(orders)
  when orders |> is_list()
  do
    spawn_link(fn -> Network.send_data_all_nodes(:elevator, :master, {:elevator_served_order, orders}) end)
  end


  defp broadcast_elevator_status(
        last_dir,
        last_floor)
  do
    spawn_link(fn -> Network.send_data_all_nodes(:elevator, :master, {:elevator_status_update, {last_dir, last_floor}}) end)
  end



###################################### Events and transitions ######################################

##### all_states #####
# received_order #
  @doc """
  Function to handle if a new order is received
  This event should be handled if the elevator is in idle, moving or door-state and NOT when
  the elevator is initializing or restarting. Could pherhaps be best to send both internal and
  external orders over UDP then... It does simplify the elevator, but adds larger requirements
  to the order-panel
  """
  def handle_event(
        :cast,
        {:received_order, new_order_list},
        state,
        %Elevator{orders: prev_orders} = elevator_data)
  when state in [:init_state, :idle_state, :door_state, :moving_state]
  do
    Logger.info("Elevator received order")

    new_elevator_data =
      case Order.check_valid_order(new_order_list) do
        :true->
          Logger.info("valid order")
          IO.inspect(new_order_list)
          # Checking if order already exists - if not, add to list and calculate next direction
          updated_order_list = Order.add_orders(new_order_list, prev_orders)
          new_elevator_data = Map.put(elevator_data, :orders, updated_order_list)
          IO.inspect(new_elevator_data)


          IO.inspect(updated_order_list)

          Storage.write(updated_order_list)

          Lights.set_order_lights(updated_order_list)

          new_elevator_data

        :false->
          Logger.info("invalid order")
          elevator_data
      end

    {:next_state, state, new_elevator_data}
  end

  def handle_event(
        :cast,
        {:received_order, _new_order_list},
        :restart_state,
        elevator_data)
  do
    Logger.info("Elevator received order(s) while in restart_state. Order(s) not accepted!")
    {:next_state, :restart_state, elevator_data}
  end


# udp_timer #
  @doc """
  Function to handle when the elevator's status must be sent to the master
  No transition
  """
  def handle_event(
        :info,
        :udp_timer,
        state,
        %Elevator{dir: dir, last_floor: last_floor} = elevator_data)
  do
    Timer.interrupt_after(self(), :udp_timer, @status_update_time)
    broadcast_elevator_status(dir, last_floor)

    {:next_state, state, elevator_data}
  end


##### init_state #####
# at_floor #
  @doc """
  Function to handle when the elevator has received a floor in init-state
  Transitions into the state 'idle_state'
  """
  def handle_event(
        :cast,
        {:at_floor, floor},
        :init_state,
        %Elevator{timer: timer} = elevator_data)
  do
    Logger.info("Elevator safe at floor after init. Transitioning into idle")

    # Since we are safe at a floor, the elevator's state is secure
    Driver.set_motor_direction(:stop)
    Process.cancel_timer(timer)

    # Reading previously saved orders, and starting timer
    stored_orders = [] #Storage.read()
    prev_orders =
      case Order.check_valid_order(stored_orders) do
        :true->
          stored_orders
        :false->
          []
      end

    new_elevator_data =
      Map.put(elevator_data, :orders, prev_orders) |>
      check_at_new_floor(floor)
    Timer.interrupt_after(self(), :udp_timer, @status_update_time)

    {:next_state, :idle_state, new_elevator_data}
  end

# timeout #
  @doc """
  Function to handle if we are stuck at init for too long
  Transitions into the state 'restart_state'
  """
  def handle_event(
        :info,
        :init_timer,
        :init_state,
        elevator_data)
  do
    Logger.info("Elevator did not get to a defined floor before timeout. Restarting")
    kill_process()
    {:next_state, :restart_state, elevator_data}
  end


##### idle_state #####

  @doc """
  Function to handle when the elevator is in idle
  It checks for any orders, and - if there are - transitions into the state 'moving_state'
  """
  def handle_event(
        :cast,
        _,
        :idle_state,
        elevator_data)
  do
    last_floor = Map.get(elevator_data, :last_floor)
    last_dir = Map.get(elevator_data, :dir)
    orders = Map.get(elevator_data, :orders)

    new_dir = calculate_optimal_direction(orders, last_dir, last_floor)

    {new_state, new_data} =
      case new_dir do
        :nil->

          {:idle_state, elevator_data}

        _->
          Logger.info("Elevator in idle, calculated new direction")
          temp_elevator_data = Map.put(elevator_data, :dir, new_dir)

          new_elevator_data = Timer.start_timer(self(), temp_elevator_data, :timer, :moving_timer, @moving_time)
          Driver.set_motor_direction(new_dir)

          {:moving_state, new_elevator_data}
      end

    {:next_state, new_state, new_data}
  end


##### moving_state #####
# at floor #
  @doc """
  Function to handle when the elevator is at the desired floor in moving state
  Transitions into door_state
  """
  def handle_event(
        :cast,
        {:at_floor, floor},
        :moving_state,
        elevator_data)
  do
    Logger.info("Elevator reached a floor while in moving_state")

    all_orders = Map.get(elevator_data, :orders)
    direction = Map.get(elevator_data, :dir)

    {order_at_floor, floor_orders} = Order.check_orders_at_floor(all_orders, floor, direction)

    # Updating moving-timer and last_floor
    temp_elevator_data = check_at_new_floor(elevator_data, floor)

    # Checking if at target floor and if there is a valid order to stop on
    {new_state, new_data} =
      case order_at_floor do
        :true->
          # The floor has an order. Stop and serve
          new_elevator_data = reached_order_floor(temp_elevator_data, floor, floor_orders)
          {:door_state, new_elevator_data}

        :false->
          {:moving_state, temp_elevator_data}
      end

    {:next_state, new_state, new_data}
  end

# min or max floor reached #
  @doc """
  Functions to handle if we have reached the top- or bottom-floor without an
  order there. These functions should not be triggered if we have an order at
  the floor, as that event should be handled above.
  Currently the elevator is set to idle, but one could argue that the elevator
  instead should be set to restart.
  """
  def handle_event(
        :cast,
        {:at_floor, _floor = @min_floor},
        :moving_state,
        %Elevator{dir: :down} = elevator_data)
  do
    Logger.info("Elevator reached min_floor while moving down")
    reached_floor_limit()
    {:next_state, :idle_state, elevator_data}
  end

  def handle_event(
        :cast,
        {:at_floor, _floor = @max_floor},
        :moving_state,
        %Elevator{dir: :up} = elevator_data)
  do
    Logger.info("Elevator reached max floor while moving up")
    reached_floor_limit()
    {:next_state, :idle_state, elevator_data}
  end

# timeout #
  @doc """
  Function to handle if the elevator hasn't reached a floor
  Transitions into restart
  """
  def handle_event(
        :info,
        :moving_timer,
        :moving_state,
        elevator_data)
  do
    Logger.info("Elevator spent too long time moving. Engine failure - restarting.")
    kill_process()
    {:next_state, :restart_state, elevator_data}
  end


##### door_state #####

# Door timer #
  @doc """
  Closes the door and transitions into idle
  """
  def handle_event(
        :info,
        :door_timer,
        :door_state,
        elevator_data)
  do
    Logger.info("Elevator closing door and going into idle")
    close_door()
    {:next_state, :idle_state, elevator_data}
  end

# at_floor #
  @doc """
  Handler that acknowledges messages from the floor-sensor that the
  elevator is at a floor. Made only to prevent the elevator from
  crashing
  """
  def handle_event(
        :cast,
        {:at_floor, floor},
        :door_state,
        elevator_data)
  do
    {:next_state, :door_state, elevator_data}
  end


##### restart_state #####

  @doc """
  Function to handle if the elevator enters a restart
  """
  def handle_event(
        _,
        _,
        :restart_state,
        elevator_data)
  do
    kill_process()
    {:next_state, :restart_state, elevator_data}
  end

  ##### Evrything else #####
  @doc """
  Function to handle if the GenStateMachine receives an unexpected event
  """
  def handle_event(
      _,
      _,
      state,
      elevator_data)
  do
    {:next_state, state, elevator_data}
  end



###################################### Actions ######################################

##### Checking floor #####

  @doc """
  Function to read the current floor indefinetly. The function does not take any interdiction
  between overflow or not. If the value 'i' results in a negative number, we just keep
  incrementing.
  A semi-while-loop is implemented, since it was observed that recursion eats the heap
  Invokes the function check_at_floor() with the data
  """
  defp read_current_floor()
  do
    Stream.iterate(0, &(&1+1)) |> Enum.reduce_while(0, fn _i, acc ->
      Process.sleep(5)
      Driver.get_floor_sensor_state() |> check_at_floor()
      {:cont, acc + 1}
    end)
  end


  @doc """
  Function that check if we are at a floor
  If true (on floor {0, 1, 2, ...}) it sends a message to the GenStateMachine-server
  """
  def check_at_floor(floor)
  when floor |> is_integer
  do
    Lights.set_floorlight(floor)
    GenStateMachine.cast(@node_name, {:at_floor, floor})
  end

  @doc """
  Function that check if we are not a floor
  If true (on floor {0, 1, 2, ...}) it sends a message to the GenStateMachine-server
  """
  def check_at_floor(floor)
  when floor |> is_atom
  do
    floor
  end


  @doc """
  Function to check if the floor 'floor' is not equivalent to the 'last_floor' in
  the struct elevator_data.
  If the floors are different, the timer is reset and 'last_floor' is updated
  """
  defp check_at_new_floor(
        elevator_data,
        floor)
  do
    last_floor = Map.get(elevator_data, :last_floor)

    cond do
      last_floor == :nil->
        Map.put(elevator_data, :last_floor, floor)

      last_floor != floor->
        temp_elevator_data = Timer.start_timer(self(), elevator_data, :timer, :moving_timer, @moving_time)
        Map.put(temp_elevator_data, :last_floor, floor)

      last_floor == floor->
        elevator_data
    end
  end


  @doc """
  Function to handle if max- or min-floor reached when no order was received there
  """
  defp reached_floor_limit()
  do
    Driver.set_motor_direction(:stop)
    IO.puts("Elevator reached limit. Stopping the elevator, and going to idle")
  end


  @doc """
  Handles what to do when a floor containing an order with type in [:cab, dir] is reached
  The function serves the order(s), updates the order-list and saves the result to Lights
  and Storage
  orders Current active orders
  dir Current elevator-direction
  floor Current elevator floor
  timer Current active timer for elevator (moving)
  """
  defp reached_order_floor(
        %Elevator{orders: order_list, dir: dir} = elevator_data,
        floor,
        floor_orders)
  when is_list(floor_orders)
  do
    Driver.set_motor_direction(:stop)
    Logger.info("Reached target floor at floor #{floor}")

    # Open door, start timer and message master
    open_door()
    timer_elevator_data = Timer.start_timer(self(), elevator_data, :timer, :door_timer, @door_time)
    broadcast_served_orders(floor_orders)

    # Remove old orders and calculate new target_order
    updated_orders = Order.remove_orders(floor_orders, order_list)

    #Storage.write(updated_orders)
    Lights.set_order_lights(updated_orders)

    Map.put(timer_elevator_data, :orders, updated_orders)
  end


##### Calculating optimal direction #####

  @doc """
  Function to find the next optimal order. The function uses the current floor and direction
  to return the next optimal direction for the elevator to serve the given orders.
  If orders == [] or floor == :nil, :nil is returned
  orders  Orders to be scanned
  dir     Current direction to check for orders
  Floor   Current floor to check for order
  """
  defp calculate_optimal_direction(
        [],
        _dir,
        _floor)
  do
    :nil
  end

  defp calculate_optimal_direction(
    _orders,
    _dir,
    :nil = _floor)
  do
    :nil
  end

  defp calculate_optimal_direction(
        orders,
        dir,
        floor)
  when floor >= @min_floor and floor <= @max_floor
  do
    optimal_floor = calculate_optimal_floor(orders, dir, floor)
    cond do
      optimal_floor > floor->
        :up
      optimal_floor < floor->
        :down
      optimal_floor == floor->
        dir
    end
  end

  @doc """
  Function to calculate the optimal floor the elevator should travel to next
  One may be worried that the function is stuck here in an endless recursion-loop since it changes
  direction if it haven't found anything. As long as there exist an order inside the elevator-space,
  the function will find it. It may be a possible bug if an order is outside of the elevator-space, but
  that is directly linked to why is it here in the first place. That bug is then related to
  calculate_optimal_direction(), as it should not invoke the function without valid orders
  """
  defp calculate_optimal_floor(
        orders,
        dir,
        floor)
  when floor >= @min_floor and floor <= @max_floor
  do
    # Check if orders on this floor, and in correct direction
    {bool_orders_on_floor, _matching_orders} = Order.check_orders_at_floor(orders, floor, dir)

    # Ugly way to recurse further
    case {bool_orders_on_floor, dir} do
      {:true, _}->
        # Orders on this floor - return the floor
        floor

      {:false, :down}->
        # No orders on this floor, and direction :down
        cond do
          floor > @min_floor->
            calculate_optimal_floor(orders, dir, floor - 1)
          floor == @min_floor->
            # Change search direction
            calculate_optimal_floor(orders, :up, floor)
        end

      {:false, :up}->
        # No orders on this floor and direction :up
        cond do
          floor < @max_floor->
            calculate_optimal_floor(orders, dir, floor + 1)
          floor == @max_floor->
            # Change search direction
            calculate_optimal_floor(orders, :down, floor)
        end
    end
  end


##### Door #####


  @doc """
  Function to open/close door
  """
  defp open_door()
  do
    Lights.set_door_light(:on)
  end
  defp close_door()
  do
    Lights.set_door_light(:off)
  end


##### Restart #####


  @doc """
  Function to kill the module in case of an error. Orders are NOT stored via this function.
  Otherwise, one may risk that old orders are overwritten, if this function is invoked during
  init. It is therefore assumed that all orders are handled when they are recieved / removed
  """
  defp kill_process()
  do
    Logger.info("Killing elevator")
    Driver.set_motor_direction(:stop)
    Process.exit(self(), :shutdown)
  end
end
