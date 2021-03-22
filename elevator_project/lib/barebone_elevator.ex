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
    Must find a way to handle motor-problems gracefully
    Must check that the idle-state works reasonably well
  """

##### Module definitions #####

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
    Logger.info("Elevator initialized")

    # Set correct elevator-state
    elevator_data = %BareElevator{
      orders: [],
      target_order: :nil,
      last_floor: :nil,
      dir: :down,
      timer: make_ref()
    }

    # Close door and set direction down
    close_door()
    Driver.set_motor_direction(:down)

    # Starting process for error-handling
    start_init_timer(elevator_data)
    spawn(fn-> read_current_floor() end)

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


##### Interface to external modules #####


  @doc """
  Function for external modules (either Panel or Master) to call when a new order is detected
  """
  def add_order()
  do
    :ok
  end

  @doc """
  Work in progress - must be decided alongside the interface of Panel and Master
  """
  def wip()
  do
    :ok
  end


###################################### Events and transitions ######################################

##### init_state #####

  @doc """
  Function to handle when the elevator has received a floor in init-state

  Transitions into the state 'idle_state'
  """
  def handle_event(
        :cast,
        {:at_floor, _floor},
        :init_state,
        %BareElevator{timer: timer} = elevator_data)
  do
    Logger.info("Elevator safe at floor after init. Transitioning into idle")
    Process.cancel_timer(timer)
    {:next_state, :idle_state, elevator_data}
  end

  @doc """
  Function to handle if we are stuck at init for too long

  Transitions into the state 'restart_state'
  """
  def handle_event(
        :cast,
        :init_timer,
        :init_state,
        elevator_data)
  do
    Logger.info("Elevator did not get to a defined floor before timeout. Restarting")
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
    Logger.info("Elevator in idle_state")

    # floor should always be an integer when in idle_state
    floor = Driver.get_floor_sensor_state()
    temp_elevator_data = calculate_target_floor(elevator_data, floor)

    target_order = Map.get(temp_elevator_data, :target_order)

    if target_order != :nil do
      dir = Map.get(temp_elevator_data, :dir)
      new_elevator_data = start_moving_timer(temp_elevator_data)
      {:next_state, :moving_state, new_elevator_data, [Driver.set_motor_direction(dir)]}
    end

    {:keep_state_and_data}
  end


##### moving_state #####

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

    target_order = Map.get(elevator_data, :target_order)
    dir = Map.get(elevator_data, :dir)

    if target_order == :nil do
      # Invalid order here! Restart as we should not be in 'moving_state' with invalid order
      {:next_state, :restart_state, elevator_data}
    end

    # Updating moving-timer and last_floor
    temp_elevator_data = check_if_at_new_floor(elevator_data, floor)

    # Checking if at target floor and if there is a valid order to stop on
    if Map.get(target_order, :order_floor) != floor do
      {:keep_state, temp_elevator_data}
    end

    if Map.get(target_order, :order_type) not in [dir, :cab] do
      {:keep_state, temp_elevator_data}
    end

    Logger.info("Elevator reached target destination")
    new_elevator_data = reached_target_floor(temp_elevator_data, floor)
    {:next_state, :door_state, new_elevator_data}
  end


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
        %BareElevator{dir: :down} = elevator_data)
  do
    Logger.info("Elevator reached min_floor while moving down")
    reached_floor_limit()
    {:next_state, :idle_state, elevator_data}
  end

  def handle_event(
        :cast,
        {:at_floor, _floor = @max_floor},
        :moving_state,
        %BareElevator{dir: :up} = elevator_data)
  do
    Logger.info("Elevator reached max floor while moving up")
    reached_floor_limit()
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
    Logger.info("Elevator spent too long time moving. Engine failure - restarting.")
    {:next_state, :restart_state, elevator_data}
  end


##### door_state #####

  @doc """
  Closes the door and transitions into idle
  """
  def handle_event(
        :cast,
        :door_timer,
        :door_state,
        elevator_data)
  do
    Logger.info("Elevator closing door and going into idle")
    close_door()
    {:next_state, :idle_state, elevator_data}
  end


##### restart_state #####

  @doc """
  Function to handle if the elevator enters a restart
  """
  def handle_event(
        :cast,
         _,
        :restart_state,
        elevator_data)
  do
    Logger.info("Elevator restarts")
    restart_process()
    {:next_state, :init_state, elevator_data}
  end


##### all_states #####

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
    Logger.info("Elevator received order from #{from}")

    # First check if the order is valid - throws an error if not (will trigger a crash)
    Order.check_valid_orders([new_order])

    # Checking if order already exists - if not, add to list, calculate next target and ack
    if new_order not in prev_orders do
      new_orders = [prev_orders | new_order]
      temp_elevator_data = Map.put(elevator_data, :orders, new_orders)

      # We have a potential bug here. Since we are using a functional language, the elevator_data that is
      # inside of the if is not equivalent to the elevator_data outside of the scope...

      new_elevator_data = calculate_target_floor(temp_elevator_data, last_floor)

      Logger.info("Order added to list")
      {:keep_state, new_elevator_data, [{:reply, from, {:ack, id}}]}
    end

    Logger.info("Order already in list")
    # Ack if already in list
    {:keep_state, elevator_data, [{:reply, from, {:ack, id}}]}
  end


  @doc """
  Function to handle when the elevator's status must be sent to the master

  No transition
  """
  def handle_event(
        :cast,
        :udp_timer,
        _,
        %BareElevator{orders: orders, dir: dir, last_floor: last_floor} = _elevator_data)
  do

    # IMPORTANT! We must find a way to handle init/restart
    # Might be a bug to use self() when sending
    Process.send(Process.whereis(:active_master), {self(), dir, last_floor, orders}, [])
    start_udp_timer()
    {:keep_state_and_data}
  end


###################################### Actions ######################################

##### Checking floor #####

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
  Function to check if the floor 'floor' is not equivalent to the 'last_floor' in
  the struct elevator_data.

  If the floors are different, the timer is reset and 'last_floor' is updated
  """
  defp check_if_at_new_floor(
        elevator_data,
        floor)
  do
    last_floor = Map.get(elevator_data, :last_floor)

    if last_floor != floor do
      temp_elevator_data = start_moving_timer(elevator_data)
      new_elevator_data = Map.put(temp_elevator_data, :last_floor, floor)

      new_elevator_data
    end

    elevator_data
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
    Logger.info("Reached target floor at floor #{floor}")

    # Open door and start timer
    open_door()
    timer_elevator_data = start_door_timer(elevator_data)

    # Remove old order and calculate new target_order
    updated_orders = remove_orders(orders, dir, floor)
    orders_elevator_data = Map.put(timer_elevator_data, :orders, updated_orders)
    new_elevator_data = calculate_target_floor(orders_elevator_data, floor)

    new_elevator_data
  end


##### Calculating optimal order/direction #####

  @doc """
  Function to calculate the next target floor and direction
  """
  defp calculate_target_floor(
        %BareElevator{
          dir: dir,
          orders: orders
        } = elevator_data,
        floor)
  do
    next_target_order = find_optimal_order(orders, dir, floor)

    temp_elevator_data = Map.put(elevator_data, :target_order, next_target_order)
    new_elevator_data = calculate_target_direction(temp_elevator_data, floor)

    new_elevator_data
  end


  @doc """
  Function to calculate the next direction the elevator should travel in

  elevator_data Struct to get the next target-floor
  floor         Current floor the elevator is in
  """
  defp calculate_target_direction(
        elevator_data,
        floor)
  do
    target_order = Map.get(elevator_data, :target_order)

    if target_order == :nil do
      Map.get(elevator_data, :dir)
    end

    target_order_floor = Map.get(target_order, :order_floor)
    if target_order_floor == floor do
      Map.get(elevator_data, :dir)
    end

    if target_order_floor > floor do
      :up
    else
      :down
    end
  end


##### Order #####

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
        _dir,
        _floor)
  do
    []
  end


  @doc """
  Function to find the next optimal order. The function uses the current floor and direction
  to return the next optimal order for the elevator to serve.
  The function changes direction it checks in if nothing is found.

  One may be worried that the function is stuck here in an endless recursion-loop since it changes
  direction if it haven't found anything. As long as there exist an order inside the elevator-space,
  the function will find it. It may be a possible bug if an order is outside of the elevator-space, but
  that is directly linked to why is it here in the first place


  orders  Orders to be scanned
  dir     Current direction to check for orders
  Floor   Current floor to check for order
  """
  defp find_optimal_order(
        orders,
        dir,
        floor) when floor >= @min_floor and floor <= @max_floor
  do
    # To prevent indefinite recursion on empty orders
    if orders == [] do
      :nil
    end

    # Check if orders on this floor, and in correct direction
    order_in_dir = Enum.find(orders, :nil, fn(element)-> match?(%Order{order_type: dir, order_floor: floor}, element) end)
    order_in_cab = Enum.find(orders, :nil, fn(element)-> match?(%Order{order_type: :cab, order_floor: floor}, element) end)

    if order_in_cab != :nil do
      order_in_cab
    end
    if order_in_dir != nil do
      order_in_cab
    end

    # No match found. Recurse on the next floor in same direction
    if dir == :down and floor != @min_floor do
      order = find_optimal_order(orders, dir, floor - 1)
      order
    end
    if dir == :up and floor != @max_floor do
      order = find_optimal_order(orders, dir, floor + 1)
      order
    end

    # Max or min floor, change search direction
    if dir == :down and floor == @min_floor do
      order = find_optimal_order(orders, :up, floor + 1)
      order
    end

    if dir == :up and floor == @max_floor do
      order = find_optimal_order(orders, :down, floor - 1)
      order
    end
  end


##### Timer #####


  @doc """
  Starts the door-timer, which signals that the elevator should
  close the door
  """
  defp start_door_timer(elevator_data)
  do
    timer = Map.get(elevator_data, :timer)
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :door_timer, @door_time)
    Map.put(elevator_data, :timer, timer)
  end


  @doc """
  Function that starts a timer to check if we are moving
  """
  defp start_moving_timer(elevator_data)
  do
    timer = Map.get(elevator_data, :timer)
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :moving_timer, @moving_time)
    Map.put(elevator_data, :timer, timer)
  end


  @doc """
  Function that starts a timer to check if init takes too long
  """
  defp start_init_timer(elevator_data)
  do
    timer = Map.get(elevator_data, :timer)
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


##### Door #####


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


##### Restart #####


  @doc """
  Function to kill the module in case of an error
  """
  defp restart_process()
  do
    # Should pherhaps consider sending a message to master or something ?
    Driver.set_motor_direction(:stop)
    Process.exit(self(), :shutdown)
  end











###################################### DEBUGGING FUNCTIONS ######################################

##### Debugging state-transitions #####

  @doc """
  Function to set the system in a desired state, with desired data

  new_state New_state for the system to be set to
  new_data  New_data the system should handle
  """
  def debugging_set_state_and_data(
        new_state,
        new_data)
  do
    GenStateMachine.cast(@node_name, {:debugging, new_state, new_data})
  end


  def handle_event(
        :cast,
        {:debugging, new_state, new_data},
        _,
        _elevator_data)
  do
    {:next_state, new_state, new_data}
  end



#####  #####








end
