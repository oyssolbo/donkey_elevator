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
    Testing

  """

##### Module definitions #####

  use GenStateMachine

  require Logger
  require Driver
  require Order
  require Lights

  @min_floor    Application.fetch_env!(:elevator_project, :min_floor)
  @max_floor    Application.fetch_env!(:elevator_project, :num_floors) + @min_floor - 1
  @cookie       Application.fetch_env!(:elevator_project, :default_cookie)

  @door_time    3000  # ms
  @moving_time  5000  # ms
  @update_time  250   # ms
  @init_time    @moving_time

  @node_name    :barebone_elevator

  @enforce_keys [:orders, :last_floor, :dir, :timer]
  defstruct     [:orders, :last_floor, :dir, :timer]



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
    data = %BareElevator{
      orders: [],
      last_floor: :nil,
      dir: :down,
      timer: make_ref()
    }

    # Close door and set direction down
    close_door()
    Driver.set_motor_direction(:down)

    # Starting process for error-handling
    elevator_data = start_init_timer(data)
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
  def delegate_order(order)
  do
    # If it only works with casting, we must ack here

    IO.puts("delegate_order invoked")
    IO.inspect(order)
    #GenStateMachine.call(@node_name, {:received_order, order})
    GenStateMachine.cast(@node_name, {:received_order, order})
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
        {:at_floor, floor},
        :init_state,
        %BareElevator{timer: timer} = elevator_data)
  do
    Logger.info("Elevator safe at floor after init. Transitioning into idle")

    # Since we are safe at a floor, the elevator's state is secure
    Process.cancel_timer(timer)
    new_elevator_data = check_at_new_floor(elevator_data, floor)
    start_udp_timer()

    {:next_state, :idle_state, new_elevator_data}
  end

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

    last_floor = Map.get(elevator_data, :last_floor)
    last_dir = Map.get(elevator_data, :dir)
    orders = Map.get(elevator_data, :orders)

    IO.inspect(orders)

    # We only get :nil (when we should have orders)
    new_dir = calculate_optimal_direction(orders, last_dir, last_floor)

    {new_state, new_data} =
      case new_dir do
        :nil->
          Logger.info("No direction calculated")
          {:idle_state, elevator_data}

        _->
          Logger.info("New direction calculated")
          temp_elevator_data = Map.put(elevator_data, :dir, new_dir)

          new_elevator_data = start_moving_timer(temp_elevator_data)
          Driver.set_motor_direction(new_dir)

          {:moving_state, new_elevator_data}
      end

    {:next_state, new_state, new_data}
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

    all_orders = Map.get(elevator_data, :orders)
    direction = Map.get(elevator_data, :dir)

    {order_at_floor, _valid_orders} = Order.check_orders_at_floor(all_orders, floor, direction)

    # Updating moving-timer and last_floor
    IO.inspect(elevator_data)
    temp_elevator_data = check_at_new_floor(elevator_data, floor)
    IO.inspect(temp_elevator_data)

    # Checking if at target floor and if there is a valid order to stop on
    {new_state, new_data} =
      case order_at_floor do
        :true->
          # The floor has an order. Stop and serve
          new_elevator_data = reached_order_floor(temp_elevator_data, floor)
          {:door_state, new_elevator_data}

        :false->
          {:moving_state, temp_elevator_data}
      end

    {:next_state, new_state, new_data}
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
        :info,
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
        :info,
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
        :cast,
        {:received_order, new_order},
        state,
        %BareElevator{orders: prev_orders, last_floor: last_floor} = elevator_data)
  do
    #Logger.info("Elevator received order from #{from}")
    Logger.info("Elevator received order")

    # First check if the order is valid - throws an error if not
    Order.check_valid_orders([new_order])

    # Checking if order already exists - if not, add to list and calculate next direction
    updated_order_list = Order.add_order(new_order, prev_orders)
    new_elevator_data = Map.put(elevator_data, :orders, updated_order_list)

    Lights.set_order_lights(updated_order_list)

    {:next_state, state, new_elevator_data}
  end

  def handle_event(
    :cast,
    {:received_order, _},
    state,
    %BareElevator{orders: prev_orders, last_floor: last_floor} = elevator_data)
  do
    #Logger.info("Elevator received order from #{from}")
    Logger.info("Elevator received order _")

    {:next_state, state, elevator_data}
  end

  def handle_event(
    :cast,
    {:received_order, new_order},
    _,
    %BareElevator{orders: prev_orders, last_floor: last_floor} = elevator_data)
  do
    #Logger.info("Elevator received order from #{from}")
    Logger.info("Elevator received order with state _")

    {:next_state, :idle_state, elevator_data}
  end


  @doc """
  Function to handle when the elevator's status must be sent to the master

  No transition
  """
  def handle_event(
        :info,
        :udp_timer,
        state,
        %BareElevator{orders: orders, dir: dir, last_floor: last_floor} = elevator_data)
  do
    start_udp_timer()

    active_master_pid = Process.whereis(:active_master)
    if active_master_pid != :nil do
      Process.send(active_master_pid, {self(), dir, last_floor, orders}, [])
    end
    {:next_state, state, elevator_data}
  end


###################################### Actions ######################################

##### Checking floor #####

  @doc """
  Function to read the current floor indefinetly. The function does not take any interdiction
  between overflow or not. If the value 'i' results in a negative number, we just keep
  incrementing.

  A while-loop is implemented, since recursion eats up the heap

  Invokes the function check_at_floor() with the data
  """
  defp read_current_floor()
  do
    Stream.iterate(0, &(&1+1)) |> Enum.reduce_while(0, fn i, acc ->
      Process.sleep(5)
      Driver.get_floor_sensor_state() |> check_at_floor()
      {:cont, acc + 1}
    end)
  end


  @doc """
  Function that check if we are at a floor

  If true (on floor {0, 1, 2, ...}) it sends a message to the GenStateMachine-server
  """
  def check_at_floor(floor) when floor |> is_integer
  do
    Lights.set_floorlight(floor)
    GenStateMachine.cast(@node_name, {:at_floor, floor})
  end

  # defp check_at_floor(floor) when floor |> is_integer
  # do
  #   Lights.set_floorlight(floor)
  #   GenStateMachine.cast(@node_name, {:at_floor, floor})
  # end


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
        temp_elevator_data = start_moving_timer(elevator_data)
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
  Function to handle if we have reached the desired floor

  orders Current active orders
  dir Current elevator-direction
  floor Current elevator floor
  timer Current active timer for elevator (moving)
  """
  defp reached_order_floor(
        %BareElevator{orders: orders, dir: dir} = elevator_data,
        floor)
  do
    Driver.set_motor_direction(:stop)
    Logger.info("Reached target floor at floor #{floor}")

    # Open door and start timer
    open_door()
    timer_elevator_data = start_door_timer(elevator_data)

    # Remove old order and calculate new target_order
    updated_orders = Order.remove_orders(orders, dir, floor)
    orders_elevator_data = Map.put(timer_elevator_data, :orders, updated_orders)

    Lights.set_order_lights(updated_orders)

    dir_opt = calculate_optimal_direction(updated_orders, dir, floor)
    Map.put(orders_elevator_data, :dir, dir_opt)
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
  def calculate_optimal_direction(
        [],
        _dir,
        _floor)
  do
    :nil
  end

  def calculate_optimal_direction(
    _orders,
    _dir,
    :nil = _floor)
  do
    :nil
  end

  def calculate_optimal_direction(
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

  It is a bug here somewhere. Somehow it returns the direction when it should return the floor (int)
  """
  def calculate_optimal_floor(
        orders,
        dir,
        floor)
  when floor >= @min_floor and floor <= @max_floor
  do
    # Check if orders on this floor, and in correct direction
    {bool_orders_on_floor, _matching_orders} = Order.check_orders_at_floor(orders, floor, dir)

    IO.inspect(floor)

    # Ugly way to recurse further
    new_floor =
      case {bool_orders_on_floor, dir} do
        {:true, _}->
          # Orders on this floor - return the floor
          IO.puts("Returning with floor set to")
          IO.inspect(floor)
          floor

        {:false, :down}->
          # No orders on this floor, and direction :down
          IO.puts("Going down with floor set to")
          IO.inspect(floor)
          cond do
            floor > @min_floor->
              calculate_optimal_direction(orders, dir, floor - 1)
            floor == @min_floor->
              # Change search direction
              calculate_optimal_direction(orders, :up, floor)
          end

        {:false, :up}->
          # No orders on this floor and direction :up
          IO.puts("Going up with floor set to")
          IO.inspect(floor)
          cond do
            floor < @max_floor->
              calculate_optimal_direction(orders, dir, floor + 1)
            floor == @max_floor->
              # Change search direction
              calculate_optimal_direction(orders, :down, floor)
          end
      end

      IO.puts("New calculated floor")
      IO.inspect(new_floor)
      new_floor
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
    Map.put(elevator_data, :timer, timer)
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
    Lights.set_door_light(:on)
  end
  defp close_door()
  do
    Lights.set_door_light(:off)
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
end


defmodule ElevatorTest do

  require BareElevator
  require Order

  def test_elevator_init()
  do
    BareElevator.start_link()
    Process.sleep(500)
  end

  def test_elevator_init_to_idle()
  do
    test_elevator_init()
    BareElevator.check_at_floor(1)
    Process.sleep(500)
  end

  def test_elevator_idle_to_moving()
  do
    # The elevator does not transition from idle to moving (order not registered)
    test_elevator_init_to_idle()
    opts = [order_id: make_ref(), order_type: :cab, order_floor: 2]
    order = struct(Order, opts)
    BareElevator.delegate_order(order)
    BareElevator.check_at_floor(1)
    Process.sleep(100)
    BareElevator.check_at_floor(1)
    Process.sleep(500)
  end

  def test_elevator_moving_to_door()
  do
    test_elevator_idle_to_moving()
    BareElevator.check_at_floor(2)
    Process.sleep(500)
  end


  def test_while()
  do
    Stream.iterate(0, &(&1+1)) |> Enum.reduce_while(0, fn i, acc ->
      IO.inspect(i)
      {:cont, acc + 1}
    end)
  end


  def test_optimal_floor()
  do
    opts1 = [order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    dir1 = :down
    floor = 2

    # Optimal floor should be floor 2
    opt_floor_test_1 = BareElevator.calculate_optimal_floor([order1, order2], dir1, floor)
    #IO.puts("Optimal should be 2")
    #IO.inspect(opt_floor_test_1)
    #IO.puts(" WHAT?? ")

    dir2 = :up
    # Optimal floor should be floor 3
    opt_floor_test_2 = BareElevator.calculate_optimal_floor([order1, order2], dir2, floor)
    #IO.puts("Optimal should be 3")
    #IO.inspect(opt_floor_test_2)

    # Optimal floor should be floor 3
    opt_floor_test_3 = BareElevator.calculate_optimal_floor([order1], dir1, floor)
    #IO.puts("Optimal should be 3")
    #IO.inspect(opt_floor_test_3)
  end


  def test_optimal_direction()
  do
    opts1 = [order_id: make_ref(), order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_id: make_ref(), order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    dir1 = :down
    floor = 2

    # Optimal dir should be :down
    opt_dir_test_1 = BareElevator.calculate_optimal_direction([order1, order2], dir1, floor)
    IO.puts("Optimal should be :down")
    IO.inspect(opt_dir_test_1)

    dir2 = :up
    # Optimal dir should be :up
    opt_dir_test_2 = BareElevator.calculate_optimal_direction([order1, order2], dir2, floor)
    IO.puts("Optimal should be :up")
    IO.inspect(opt_dir_test_2)

    # Optimal dir should be :up
    opt_dir_test_3 = BareElevator.calculate_optimal_direction([order1], dir1, floor)
    IO.puts("Optimal should be :up")
    IO.inspect(opt_dir_test_3)

  end

  def test_get_order_at_floor()
  do
    opts1 = [order_id: make_ref(), order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_id: make_ref(), order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    order_floor_1_down = Order.get_order_at_floor([order1, order2], 1, :down)
    IO.puts("Orders at floor 1 going down")
    IO.inspect(order_floor_1_down)

    order_floor_1_up = Order.get_order_at_floor([order1, order2], 1, :up)
    IO.puts("Orders at floor 1 going up")
    IO.inspect(order_floor_1_up)

    order_floor_3_down = Order.get_order_at_floor([order1, order2], 3, :down)
    IO.puts("Orders at floor 3 going down")
    IO.inspect(order_floor_3_down)

    order_floor_3_up = Order.get_order_at_floor([order1, order2], 3, :up)
    IO.puts("Orders at floor 3 going up")
    IO.inspect(order_floor_3_up)


    IO.puts("Checking orders at floor")

  end


  def test_check_order_at_floor()
  do
    opts1 = [order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    dir = :down

    {bool, order} = Order.check_orders_at_floor([order1, order2], 1, :up)
    case {bool, dir} do
      {:true, _} ->
        IO.puts("OK")
      {:false, :up} ->
        IO.puts("Not OK - up")
      {:false, :down} ->
        IO.puts("Not OK - down")
    end
  end
end
