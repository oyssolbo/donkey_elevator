defmodule BareElevator do
  @moduledoc """
  Barebones elevator-module that must be developed further.

  Requirements:
    - Driver
    - Network
    - Order

  To be implemented:
    - Lights
    - Orderpanel
    - Storage


  TODO:
    Must use the orders to calculate the direction the elevator must travel in
  """

  use GenStateMachine

  require Logger
  require Driver
  require Order

  @min_floor    Application.fetch_env!(:elevator_project, :min_floor)
  @max_floor    Application.fetch_env!(:elevator_project, :num_floors) + @min_floor - 1
  @cookie       Application.fetch_env!(:elevator_project, :default_cookie)

  @door_time    3000  # ms
  @moving_time  5000  # ms
  @update_time  250   # ms
  @init_time    @moving_time

  @node_name    :barebone_elevator

  @enforce_keys [:orders, :target_order, :last_floor, :dir, :timer]
  defstruct     [:orders, :target_order, :last_floor, :dir, :timer]


  @doc """
  Function to initialize the elevator, and tries to get the elevator into a defined state.

  The function
    - establishes connection to GenStateMachine-server
    - stores the current data on the server
    - spawns a process to continously check the state of the elevator
    - sets engine direction down
  """
  def init() do
    Logger.info("Elevator initialized")

    # Set correct elevator-state
    elevator_data = %BareElevator{
      orders: [],
      target_order: :nil,
      last_floor: :nil,
      dir: :down,
      timer: make_ref()
    }

    # Must have a way to init the elevator-node

    # Starting a link to the server (connects the module to the server)
    start_link({:init_state, elevator_data})

    # Spawning a process to continously check the floor
    spawn(fn-> read_current_floor() end)

    # Close door and set direction down
    close_door()
    Driver.set_motor_direction(:down)
  end


  @doc """
  Function to link to the GenStateMachine-server
  """
  def start_link(init_arg \\ [:init_state]) do
    server_opts = [name: @node_name]
    GenStateMachine.start_link(__MODULE__, init_arg, server_opts)
  end


  @doc """
  Function to stop the elevator in case of the GenStateMachine-server crashes
  """
  def terminate(_reason, _state) do
    Logger.info("Elevator given order to terminate. Terminating")
    Driver.set_motor_direction(:stop)
    Process.exit(self(), :normal)
  end



################################################## Events #####################################################

  @doc """
  Function to handle if a new order is received

  This event should be handled if the elevator is in idle, moving or door-state and NOT when
  the elevator is initializing or restarting. Could pherhaps be best to send both internal and
  external orders over UDP then... It does simplify the elevator, but adds larger requirements
  to the order-panel
  """
  def handle_event(
        {:call, from},
        {:received_order, %Order{order_id: id} = new_order},
        _,
        %BareElevator{orders: prev_orders, last_floor: last_floor} = elevator_data)
    do
    # First check if the order is valid - throws an error if not (will trigger a crash)
    Order.check_valid_orders([new_order])

    # Checking if order already exists - if not, add to list
    if new_order not in prev_orders do
      new_orders = [prev_orders | new_order]
      elevator_data = Map.put(elevator_data, :orders, new_orders)
    end

    # Calculate next target_order
    elevator_data = calculate_target_floor(elevator_data, last_floor)

    {:keep_state, elevator_data, {:reply, from, {:ack, id}}}
  end


  @doc """
  Function to handle when the elevator is at the desired floor in moving state

  Transitions into door_state
  """
  def handle_event(
        :cast,
        {:at_floor, floor},
        :moving_state,
        %BareElevator{orders: orders, target_order: target_order, dir: dir, timer: timer} = elevator_data)
  do
    # Checking if at target floor and if there is a valid order to stop on
    # Must be a better way to implement this! Ugly to keep one order as a priority/target
    if Map.get(target_order, :order_floor) != floor do
      {:keep_state_and_data}
    end

    if not Map.get(target_order, :order_type) in [dir, :cab] do
      {:keep_state_and_data}
    end

    new_elevator_data = reached_target_floor(elevator_data, floor)
    {:next_state, :door_state, new_elevator_data}
  end


  @doc """
  Function to handle when the elevator has received a floor in init-state

  Transitions into the state 'idle_state'
  """
  def handle_event(
        :cast,
        {:at_floor, floor},
        :init_state,
        %BareElevator{timer: timer} = elevator_data)
  do

    Process.cancel_timer(timer)
    {:next_state, :idle_state, elevator_data}
  end


  @doc """
  Functions to handle if we have reached the top- or bottom-floor without an
  order there. These functions should not be triggered if we have an order at
  the floor, as that event should be handled above.
  """
  def handle_event(
        :cast,
        {:at_floor, floor = @min_floor},
        :moving_state,
        %BareElevator{dir: :down} = elevator_data)
  do
    reached_floor_limit()
    {:next_state, :restart_state, elevator_data}
  end

  def handle_event(
        :cast,
        {:at_floor, floor = @max_floor},
        :moving_state,
        %BareElevator{dir: :up} = elevator_data)
  do
    reached_floor_limit()
    {:next_state, :restart_state, elevator_data}
  end


  @doc """
  Function to handle if the elevator enters a restart
  """
  def handle_event(
        :cast,
         _,
         :restart_state,
         elevator_data)
  do
    restart_process()
    {:next_state, :init_state, elevator_data}
  end


  @doc """
  Function that handles if the door has been open for too long

  Closes the door and enters idle_state
  """
  def handle_event(
        :cast,
        :door_timer,
        :door_state,
        elevator_data)
  do
    close_door()
    {:next_state, :idle_state, elevator_data}
  end


  @doc """
  Function to handle if the elevator hasn't reached a floor

  Transitions into restart
  """
  def handle_event(
        :cast,
        :moving_timer,
        :moving_state,
        elevator_data)
  do
    {:next_state, :restart_state, elevator_data}
  end


  @doc """
  Function to handle when the elevator's status must be sent to the master

  No transition
  """
  def handle_event(
        :cast,
        :udp_timer,
        _,
        %BareElevator{orders: orders, dir: dir, last_floor: last_floor} = elevator_data)
  do

    # IMPORTANT! We must find a way to handle init/restart
    # Might be a bug to use self() when sending
    Process.send(Process.whereis(:active_master), {self(), dir, last_floor, orders}, [])
    start_udp_timer()
    {:keep_state_and_data}
  end


  @doc """
  Function to handle if we are stuck at init for too long

  Restarts the process
  """
  def handle_event(
        :cast,
        :init_timer,
        :init_state,
        elevator_data)
  do
    {:next_state, :restart_state, elevator_data}
  end



  @doc """
  Function that handles when the next priority order has been updated
  """
  def handle_event(
        :cast,
        :designated_order,
        :idle_state,
        elevator_data)
  do

  end



################################################ Actions ######################################################

  @doc """
  Function to read the current floor indefinetly

  Invokes the function check_at_floor() with the data
  """
  defp read_current_floor()
  do
    Driver.get_floor_sensor_state() |> check_at_floor()
    read_current_floor()
  end


  @doc """
  Function that check if we are at a floor

  If true (on floor {0, 1, 2, ...}) it sends a message to the GenStateMachine-server
  """
  defp check_at_floor(floor) when floor |> is_integer
  do
    Driver.set_floor_indicator(floor)
    GenStateMachine.cast(@node_name, {:at_floor, floor})
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
  Function to handle if we have reached the desired floor

  orders Current active orders
  dir Current elevator-direction
  floor Current elevator floor
  timer Current active timer for elevator (moving)
  """
  defp reached_target_floor(
        %BareElevator{orders: orders, dir: dir} = elevator_data,
        floor)
  do
    Driver.set_motor_direction(:stop)
    IO.puts("Reached target floor at floor")
    IO.inspect(floor)

    # Open door and start timer
    open_door()
    elevator_data = start_door_timer(elevator_data)

    # Remove old order and calculate new target_order
    updated_orders = remove_orders(orders, dir, floor)
    elevator_data = Map.put(elevator_data, :orders, updated_orders)
    elevator_data = calculate_target_floor(elevator_data, floor)

    elevator_data
  end


  @doc """
  Function to remove all orders from the list with the current floor and direction

  first_order First order in the order-list
  rest_orders Rest of the orders in the order-list
  dir Direction of elevator
  floor Current floor the elevator is in

  Returns
  updated_orders List of orders where the old ones are deleted
  """
  defp remove_orders(
        [%Order{order_type: order_type, order_floor: order_floor} = first_order | rest_orders],
        dir,
        floor)
  do
    if order_type not in [dir, :cab] or order_floor != floor do
      [first_order | remove_orders(rest_orders, dir, floor)]
    else
      remove_orders(rest_orders, dir, floor)
    end
  end

  defp remove_orders(
        [],
        dir,
        floor)
  do
    []
  end

  @doc """
  Function to calculate the next target floor and direction
  """
  defp calculate_target_floor(
        %BareElevator{dir: dir, orders: orders} = elevator_data,
        floor)
  do
    {next_target_order, next_direction} = find_optimal_order(orders, dir, floor)

    temp_elevator_data = Map.put(elevator_data, :target_order, next_target_order)
    new_elevator_data = Map.put(temp_elevator_data, :dir, next_direction)

    new_elevator_data
  end

  @doc """
  Function to find the next optimal order. The function uses the current floor and direction
  to return the next optimal order for the elevator to serve.
  The function changes direction it checks in if nothing is found.

  One may be worried that the function is stuck here in an endless recursion-loop since it changes
  direction if it haven't found anything. As long as there exist an order inside the elevator-space,
  the function will find it. It may be a possible bug if an order is outside of the elevator-space, but
  that is directly linked to why is it here in the first place


  orders Orders to be scanned
  dir Current direction to check for orders
  Floor Current floor to check for order
  """
  defp find_optimal_order(
        orders,
        dir,
        floor) when floor >= @min_floor and floor <= @max_floor
  do
    # To prevent indefinite recursion on empty orders
    if orders == [] do
      {:nil, dir}
    end

    # Check if orders on this floor, and in correct direction
    order_in_dir = Enum.find(orders, :nil, fn(element)-> match?({:order_type, dir, :order_floor, floor}, element) end)
    order_in_cab = Enum.find(orders, :nil, fn(element)-> match?({:order_type, :cab, :order_floor, floor}, element) end)

    if order_in_cab != :nil do
      {order_in_cab, dir}
    end
    if order_in_dir != nil do
      {order_in_cab, dir}
    end

    # No match found. Recurse on the next floor in same direction
    if dir == :down and floor != @min_floor do
      {order, dir} = find_optimal_order(orders, dir, floor - 1)
      {order, dir}
    end
    if dir == :up and floor != @max_floor do
      {order, dir} = find_optimal_order(orders, dir, floor + 1)
      {order, dir}
    end

    # Max or min floor, change search direction
    if dir == :down and floor == @min_floor do
      {order, dir} = find_optimal_order(orders, :up, floor + 1)
      {order, dir}
    end

    if dir == :up and floor == @max_floor do
      {order, dir} = find_optimal_order(orders, :down, floor - 1)
      {order, dir}
    end
  end


  @doc """
  Starts the door-timer, which signals that the elevator should
  close the door
  """
  defp start_door_timer(%BareElevator{timer: timer} = elevator_data)
  do
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :door_timer, @door_time)
    new_elevator_data = Map.put(elevator_data, :timer, timer)

    new_elevator_data
  end


  @doc """
  Function that starts a timer to check if we are moving

  last_floor Int used to indicate the last registered floor
  """
  defp start_moving_timer(%BareElevator{timer: timer} = elevator_data)
  do
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :moving_timer, @moving_time)
    new_elevator_data = Map.put(elevator_data, :timer, timer)

    new_elevator_data
  end


  @doc """
  Function that starts a timer to check if init takes too long
  """
  defp start_init_timer(%BareElevator{timer: timer} = elevator_data)
  do
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :init_timer, @init_time)
    new_elevator_data = Map.put(elevator_data, :timer, timer)

    new_elevator_data
  end

  @doc """
  Function to start a timer to send updates over UDP to the master
  """
  defp start_udp_timer()
  do
    Process.send_after(self(), :udp_timer, @update_time)
  end


  @doc """
  Function to open/close door
  """
  defp open_door()
  do
    Driver.set_door_open_light(:on)
  end
  defp close_door()
  do
    Driver.set_door_open_light(:off)
  end


  @doc """
  Function to kill the module in case of an error
  """
  defp restart_process()
  do
    # Should pherhaps consider sending a message to master or something ?
    Driver.set_motor_direction(:stop)
    Process.exit(self(), :shutdown)
  end
end
