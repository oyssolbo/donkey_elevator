defmodule BareElevator do
  @moduledoc """
  Barebones elevator-module. Should initialize the elevator, and let it run between
  first and fourth floor
  """

  use GenStateMachine
  require Driver

  @min_floor 0
  @max_floor 3
  @node_name :barebone_elevator
  @enforce_keys [:target_floor, :dir]

  defstruct [:target_floor, :dir]

  # Start link to the GenServer
  def start_link(init_arg \\ []) do
    server_opts = [name: @node_name]
    GenStateMachine.start_link(__MODULE__, init_arg, server_opts)
  end

  # Init-function that runs the elevator down
  def init(init_arg \\ []) do
    # Set direction down
    Driver.set_motor_direction(:down)

    # Set correct elevator-state
    elevator_data = %BareElevator{
      target_floor: :nil,
      dir: :down
    }

    # Spawning processs to continously check floor
    spawn(fn-> read_current_floor() end)

    {:ok, :init_state, elevator_data}
  end


  # Terminating-function
  def terminate(_reason, _state) do
    Driver.set_motor_direction(:stop)
  end


  # Function that checks if we are at a floor
  defp read_current_floor() do
    Driver.get_floor_sensor_state() |> check_at_floor()
    read_current_floor()
  end


  # Function that checks if we are at a given floor. Create an asynch request if true
  defp check_at_floor(floor) when floor |> is_integer do
    GenStateMachine.cast(@node_name, {:at_floor, floor})
  end


  # Function to handle if we have reached a desired floor
  def handle_event(:cast, {:at_floor, floor}, :moving,
        %BareElevator{target_floor: target_floor = floor} = elevator_data) do

    # If we have reached the desired floor then stop
    actions = [Driver.set_engine_direction(:stop)]
    {:next_state, :idle, actions}
  end


  # Functions to handle if we have reached either the top or the bottom-floor
  def handle_event(:cast, {:at_floor, floor = @min_floor}, :moving,
        %BareElevator{dir: :down} = elevator_data) do

    # Set state to idle and stop engine
    {:next_state, :idle, reached_floor_limit()}
  end


  def handle_event(:cast, {:at_floor, floor = @max_floor}, :moving,
  %BareElevator{dir: :up} = elevator_data) do

    # Set state to idle and stop engine
    {:next_state, :idle, reached_floor_limit()}
  end


  # Function to handle if max or min-floor reached
  defp reached_floor_limit() do
    Driver.set_engine_direction(:stop)
  end


  # Function to be called when we have reached the target floor
  def reached_target_floor() do
    # Must update the order here somehow
    Driver.set_engine_direction(:stop)
  end

end
