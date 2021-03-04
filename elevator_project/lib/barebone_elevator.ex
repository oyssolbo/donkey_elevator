defmodule BareElevator do
  @moduledoc """
  Barebones elevator-module that must be developed further.

  The module uses


  Requirements:
    - Driver
    - Network
  """

  use Logger
  use GenStateMachine

  require Driver

  @min_floor 0
  @max_floor 3
  @node_name :barebone_elevator
  @enforce_keys [:target_floor, :dir, :timer]

  defstruct [:target_floor, :dir, :timer]


  @doc """
  Function to initialize the elevator, and tries to get the elevator into a defined state.

  The function does:
    - establishes conenction to GenStateMachine-server
    - stores the current data on the server
    - spawns a process to continously check the state of the elevator
    - sets engine direction down
  """
  def init() do
    # Set correct elevator-state
    elevator_data = %BareElevator{
      target_floor: :nil,
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
    Driver.set_motor_direction(:stop)
  end



################################################## Events #####################################################

  @doc """
  Function to handle if received a new order
  """
  def handle_event(:cast, {:received_order, order}) do
    # Do something
    # Unsure how this will work and how to even store the current orders given
    # to the elevator
  end


  @doc """
  Function to handle when the elevator is at the desired floor in moving state

  Transitions into
  """
  def handle_event(:cast, {:at_floor, floor}, :moving_state,
        %BareElevator{target_floor: target_floor = floor} = elevator_data) do

    # If we have reached the desired floor then stop and open door
    actions = [reached_target_floor(), ]
    {:next_state, :door_state, reached_target_floor()}
  end


  @doc """
  Function to handle when the elevator has received a floor in init-state

  Transitions into the state 'idle_state'
  """
  def handle_event(:cast, {:at_floor, floor}, :init_state) do
    {:next_state, :idle_state, reached_target_floor()}
  end


  @doc """
  Functions to handle if we have reached the top- or bottom-floor without an
  order there
  """
  def handle_event(:cast, {:at_floor, floor = @min_floor}, :moving_state,
        %BareElevator{dir: :down} = elevator_data) do
    {:next_state, :idle_state, reached_floor_limit()}
  end
  def handle_event(:cast, {:at_floor, floor = @max_floor}, :moving_state,
  %BareElevator{dir: :up} = elevator_data) do
    {:next_state, :idle_state, reached_floor_limit()}
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
  Function to handle if max- or min-floor reached
  """
  defp reached_floor_limit() do
    Driver.set_motor_direction(:stop)
    IO.puts("Elevator reached limit. Stopping the elevator, and going to idle")
  end


  @doc """
  Function to handle if we have reached the desired floor
  """
  defp reached_target_floor() do
    # Must update the order here somehow
    Driver.set_motor_direction(:stop)
    IO.puts("Reached the desired floor")
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

end
