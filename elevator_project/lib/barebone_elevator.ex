defmodule BareElevator do
  @moduledoc """
  Barebones elevator-module that must be developed further.

  Requirements:
    - Driver
    - Network

  To be implemented:
    - Lights
    - Orderpanel
    - Storage
  """

  use GenStateMachine

  require Logger
  require Driver

  @min_floor    0
  @max_floor    3
  @door_time    3000  # ms
  @moving_time  5000  # ms
  @update_time  250   # ms
  @init_time    @moving_time

  @node_name    :barebone_elevator
  @enforce_keys [:orders, :target_floor, :last_floor, :dir, :timer]


  defstruct     [:orders, :target_floor, :last_floor, :dir, :timer]


  @doc """
  Function to initialize the elevator, and tries to get the elevator into a defined state.

  The function does:
    - establishes connection to GenStateMachine-server
    - stores the current data on the server
    - spawns a process to continously check the state of the elevator
    - sets engine direction down
  """
  def init() do
    # Set correct elevator-state
    elevator_data = %BareElevator{
      orders: [],
      target_floor: :nil,
      last_floor: :nil,
      dir: :down,
      timer: make_ref()
    }

    # Must have a way to init the elevator-node

    # Starting a link to the server (connects the module to the server)
    start_link({:init_state, elevator_data})

    # Spawning a process to continously check the floor
    spawn(fn-> read_current_floor() end)

    # Set direction down
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
  def handle_event(:cast, {:received_order, order}, _, %BareElevator{orders: orders} = elevator_data) do
    # First check if the order is invalid

    # Add the order to the elevator

    # Acknowledge the order

    # Calculate next direction
  end


  @doc """
  Function to handle when the elevator is at the desired floor in moving state

  Transitions into door_state
  """
  def handle_event(:cast, {:at_floor, floor}, :moving_state,
        %BareElevator{target_floor: target_floor = floor, timer: timer} = elevator_data) do

    # We have reached the desired floor
    actions = [reached_target_floor(elevator_data)] # Have to set the new floor somehow
    {:next_state, :door_state, actions}
  end


  @doc """
  Function to handle when the elevator has received a floor in init-state

  Transitions into the state 'idle_state'
  """
  def handle_event(:cast, {:at_floor, floor}, :init_state,
        %BareElevator{timer: timer, } = elevator_data) do

    Process.cancel_timer(timer)
    {:next_state, :idle_state, elevator_data}
  end


  @doc """
  Functions to handle if we have reached the top- or bottom-floor without an
  order there. These functions should not be triggered if we have an order at
  the floor, as that event should be handled above.
  """
  def handle_event(:cast, {:at_floor, floor = @min_floor}, :moving_state,
        %BareElevator{dir: :down} = elevator_data) do
    {:next_state, :restart_state, elevator_data, [reached_floor_limit()]}
  end
  def handle_event(:cast, {:at_floor, floor = @max_floor}, :moving_state,
        %BareElevator{dir: :up} = elevator_data) do
    {:next_state, :restart_state, elevator_data, [reached_floor_limit()]}
  end


  @doc """
  Function to handle if the elevator enters a restart
  """
  def handle_event(:cast, _, :restart_state, elevator_data) do
    {:next_state, :init_state, elevator_data, [restart_process()]}
  end


  @doc """
  Function that handles if the door has been open for too long

  Closes the door and enters idle_state
  """
  def handle_event(:cast, :door_timer, :door_state, elevator_data) do
    {:next_state, :idle_state, elevator_data, [close_door()]}
  end


  @doc """
  Function to handle if the elevator hasn't reached a floor

  Transitions into restart
  """
  def handle_event(:cast, :moving_timer, :moving_state, elevator_data) do
    {:next_state, :restart_state, elevator_data}
  end


  @doc """
  Function to handle when the elevator's status must be sent to the master

  No transition
  """
  def handle_event(:cast, :udp_timer, _,
        %BareElevator{orders: orders, dir: dir, last_floor: last_floor} = elevator_data) do

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
  def handle_event(:cast, :init_timer, :init_state, elevator_data) do
    {:next_state, :restart_state, elevator_data}
  end



  @doc """
  Function that handles when the next priority order has been updated
  """
  def handle_event(:cast, :designated_order, :idle_state, elevator_data) do

  end



################################################ Actions ######################################################

  @doc """
  Function to read the current floor indefinetly

  Invokes the function check_at_floor() with the data
  """
  defp read_current_floor() do
    Driver.get_floor_sensor_state() |> check_at_floor()
    read_current_floor()
  end


  @doc """
  Function that check if we are at a floor

  If true (on floor {0, 1, 2, ...}) it sends a message to the GenStateMachine-server
  """
  defp check_at_floor(floor) when floor |> is_integer do
    Driver.set_floor_indicator(floor)
    GenStateMachine.cast(@node_name, {:at_floor, floor})
  end


  @doc """
  Function to handle if max- or min-floor reached when no order was received there
  """
  defp reached_floor_limit() do
    Driver.set_motor_direction(:stop)
    IO.puts("Elevator reached limit. Stopping the elevator, and going to idle")
  end


  @doc """
  Function to handle if we have reached the desired floor
  """
  defp reached_target_floor(elevator_data) do
    # Must update the order here somehow
    Driver.set_motor_direction(:stop)
    IO.puts("Reached the desired floor")
    open_door()
    start_door_timer(elevator_data)
  end


  @doc """
  Function to calculate the direction to the next order
  """
  defp calculate_target_floor(%BareElevator{dir: dir, orders: orders} = elevator_data) do
    # Must be calculated based on the last floor, direction and the given orders
    if dir == :down do
      calculate_orders_down()
      calculate_orders_up()
    end
    if dir == :up do
      calculate_orders_up()
      calculate_orders_down()
    end
  end

  defp calculate_orders_down() do

  end

  defp calculate_orders_up() do

  end


  @doc """
  Starts the door-timer, which signals that the elevator should
  close the door
  """
  defp start_door_timer(%BareElevator{timer: timer} = elevator_data) do
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :door_timer, @door_time)
    new_data = Map.put(elevator_data, :timer, timer)
  end


  @doc """
  Function that starts a timer to check if we are moving

  last_floor Int used to indicate the last registered floor
  """
  defp start_moving_timer(%BareElevator{timer: timer} = elevator_data) do
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :moving_timer, @moving_time)
    new_data = Map.put(elevator_data, :timer, timer)
  end


  @doc """
  Function that starts a timer to check if init takes too long
  """
  defp start_init_timer(%BareElevator{timer: timer} = elevator_data) do
    Process.cancel_timer(timer)
    timer = Process.send_after(self(), :init_timer, @init_time)
    new_data = Map.put(elevator_data, :timer, timer)
  end

  @doc """
  Function to start a timer to send updates over UDP to the master
  """
  defp start_udp_timer() do
    Process.send_after(self(), :udp_timer, @update_time)
  end


  @doc """
  Function to open/close door
  """
  defp open_door() do
    Driver.set_door_open_light(:on)
  end
  defp close_door() do
    Driver.set_door_open_light(:off)
  end


  @doc """
  Function to kill the module in case of an error
  """
  defp restart_process() do
    # Should pherhaps consider sending a message to master or something ?
    Driver.set_motor_direction(:stop)
    Process.exit(self(), :shutdown)
  end

end
