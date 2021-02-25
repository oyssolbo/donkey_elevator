defmodule Elevator_data do

end

defmodule ElevatorFailure do
  @moduledoc """
  Draft of a module implementing the FSM for failure

  It is chosen to separate this to its own module such that it
  is easier to add other failure-modes and separate the failure from
  the rest of the elevator

  It receives the current elevator-state through message-passing

  Errors that must be handled as of 24.02.21
  -timeout_door
  -timeout_elevator_timeout
  """

  use GenServer
  require Logger


  @node_name              :elevator_fsm   # Name of the node
  @timer_door             3000            # Timer for door                            [ms]
  @timer_message          500             # Timer for message lost (pherhaps drop)    [ms]
  @timer_elevator_stuck   5000            # Timer if elevator stuck in the same spot  [ms]
  @keys [:state, :order, :floor, :dir, :timer]


  # :state  //  Current elevator_state
  # :order  //  Current elevator_order
  # :floor  //  Current elevator_floor
  # :dir    //  Current elevator_direction
  # _timer  //  Watchdog for either door or timeout
  # priority_order // Random order given to an elevator to detect if the engine
  #                     can be recovered
  defstruct :state, :order, :floor, :dir, :timer, :priority_order

  # Starting link to the GenServer
  def start_link(init_arg \\ []) do
    GenServer.start_link(__MODULE__, init_arg, name: @name)
  end

  data = %Elevator_data{
    state: :init,
    order: :nil,
    floor: :nil,
    dir: :down,
    timer: make_ref(),
    priority_order: :nil
  }



  ############################### MUST BE AUTOMATED ################################
  @max_floor 4
  @min_floor 1


  ################################## Handle calls ##################################

  @doc """
  @brief Function to handle if the door has been open for too long
          The function tries to shut the door, until the elevator door
          can be closed again
  """
  def handle_call(:timeout_door, _from,
        %Elevator_data{state: :emergency} = data) do

    # Must set the cost of the elevator to infty as long as it is in this state

    # Logging the call and switching to :door-state
    IO.puts("Warning. Door has timeout. Tries to close")
    Logger.error("Elevator_data timeout :timeout_door")
    {:reply, {:ok, :door}, data}
  end


  @doc """
  @brief Function to handle if the motor has been destroyed/shut down and the
          network still has communication. Tries to move the elevator with an
          executive order
  """
  def handle_call(:timeout_position, _from,
        %Elevator_data{state: :emergency, floor: current_floor} = data) do

    # Must set the cost of the elevator to infty as long as it is in this state

    # Logging the error
    IO.puts("Warning. The elevator has been in the same position for too long. Tries to move")
    Logger.error("Elevator_data timeout :timeout_position")

    # Calculating the priority-order
    if current_floor == @max_floor or current_floor == @min_floor do
      priority_order = @max_floor - @min_floor
    else
      priority_order = @min_floor
    end
    Logger.info("Trying to restore using priority order #{priority_order}")

    # Setting the next-state
    data.priority_order = priority_order

    {:reply, {:ok, priority_order}, data} # order to priority_floor != current_floor
  end


  @doc """
  @brief Function to solve if stop-button pressed
  """
  def handle_call(:stop_activated, _from,
        %Elevator_data{state: :emergency} = data) do

    # Must set the cost of the elevator to infty as long as it is in this state

    # Must wait until the stop-button is dropped again
    {:noreply, {:ok, :wait}, data}

  end


  @doc """
  @brief Function to handle all other emergency-cases
  """
  def handle_call(_, _from,
        %Elevator_data{state: :emergency} = data) do

    # Must set the cost of the elevator to infty as long as it is in this state

    # Should pherhaps just throw an error such that the elevator can be inited again
    data.state = :init
    {:reply, {:error, :init}, data}

  end

end


defmodule ElevatorDoor do
  @moduledoc """

  """

end
