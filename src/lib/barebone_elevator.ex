defmodule BareElevator do
  @moduledoc """
  Barebones elevator-module. Should initialize the elevator, and let it run between
  first and fourth floor
  """

  use GenServer
  require Driver

  @min_floor 1
  @max_floor 4
  @node_name :barebone_elevator
  @enforce_keys [:state, :floor, :dir]

  defstruct [:state, :floor, :dir]

  # Start link to the GenServer
  def start_link(init_arg \\ []) do
    server_opts = [name: @node_name]
    GenServer.start_link(__MODULE__, init_arg, server_opts)
  end


  # Init-function that runs the elevator down
  def init(init_arg \\ []) do
    # Set direction down
    Driver.set_motor_direction(:down)

    # Set correct elevator-state
    elevator_data = %BareElevator{
      state: :init,
      floor: :nil,
      dir: :down
    }

    {:ok, elevator_data}
  end

  # Terminating-function
  def terminate(_reason, _state) do
    Driver.set_motor_direction(:stop)
  end


  # Function that checks if we are at a floor. Messages the FSM which floor we are at
  def at_floor(floor) when floor |> is_integer do
    GenServer.cast(@node_name, {:at_floor, floor})
  end


  # Function for detecting if we are at the top or bottom-floor
  # Changes direction if that is the case
  def handle_info(:at_floor, %BareElevator{floor: floor = @min_floor} = elevator_data) do
    # Change direction and state upwards
    data = move_elevator(:up, floor, elevator_data)
    {:noreply, data}
  end

  def handle_info(:at_floor, %BareElevator{floor: floor = @max_floor} = elevator_data) do
    # Change direction and state upwards
    data = move_elevator(:down, floor, elevator_data)
    {:noreply, data}
  end

  defp move_elevator(dir, floor, elevator_data) when floor |> is_integer and dir |> is_atom do
    "At floor #{floor}. Moving " <> to_string(dir) |> IO.puts
    Driver.set_motor_direction(:dir)
    Map.put(elevator_data, :dir, dir)
    elevator_data
  end

end
