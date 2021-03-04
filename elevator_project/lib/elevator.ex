# defmodule ElevatorData do
#   @moduledoc """
#   Module for implementing the struct containing the elevator's data
#   """

#   use GenServer

#   @node_name            :elevator_data
#   #@enforce_keys         [:state, :order, :floor, :dir, :cost]

#   #defstruct [:state, :order, :floor, :dir, :cost]

#   def init(:elevator_data) do
#     elevator_data = %ElevatorData{
#       state: :init,
#       order: :nil,
#       floor: :nil,
#       dir: :nil
#       #cost: :nil
#     }

#     {:ok, elevator_data}
#   end
# end


# defmodule ElevatorFailure do
#   @moduledoc """
#   Draft of a module implementing the FSM for failure

#   It is chosen to separate this to its own module such that it
#   is easier to add other failure-modes and separate the failure from
#   the rest of the elevator

#   It receives the current elevator-state through message-passing

#   Errors that must be handled as of 24.02.21
#   -timeout_door
#   -timeout_elevator_timeout
#   -stop
#   """

#   use GenServer

#   require Logger
#   require ElevatorData

#   @node_name              :elevator_failure   # Name of the node
#   @timer_message          500                 # Timer for message lost (pherhaps drop)    [ms]
#   @timer_elevator_stuck   5000                # Timer if elevator stuck in the same spot  [ms]


#   # :state  //  Current elevator_state
#   # :order  //  Current elevator_order
#   # :floor  //  Current elevator_floor
#   # :dir    //  Current elevator_direction
#   # _timer  //  Watchdog for either door or timeout
#   # priority_order // Random order given to an elevator to detect if the engine
#   #                     can be recovered
#   # defstruct :state, :order, :floor, :dir, :timer, :priority_order

#   # Starting link to the GenServer
#   def start_link(init_arg \\ []) do
#     GenServer.start_link(__MODULE__, init_arg, name: @name)
#   end



#   ############################### MUST BE AUTOMATED ################################
#   @max_floor 4
#   @min_floor 1


#   ################################## Handle calls ##################################

#   @doc """
#   @brief Function to handle if the door has been open for too long
#           The function tries to shut the door, until the elevator door
#           can be closed again
#   """
#   def handle_call(:timeout_door, _from,
#         %ElevatorData{state: :emergency} = data) do

#     # Must set the cost of the elevator to infty as long as it is in this state


#     # Logging the call and switching to :door-state
#     IO.puts("Warning. Door has timeout. Tries to close")
#     Logger.error("ElevatorData timeout :timeout_door")
#     {:reply, {:ok, :door}, data}
#   end


#   @doc """
#   @brief Function to handle if the motor has been destroyed/shut down and the
#           network still has communication. Tries to move the elevator with an
#           executive order
#   """
#   def handle_call(:timeout_position, _from,
#         %ElevatorData{state: :emergency, dir: direction, floor: current_floor} = data) do

#     # Must set the cost of the elevator to infty as long as it is in this state

#     # Logging the error
#     IO.puts("Warning. The elevator has been in the same position for too long. Tries to move")
#     Logger.error("ElevatorData timeout :timeout_position")

#     # Calculating which order to add to the queue
#     direction = :nil
#     target_floor = -1
#     case direction do
#       :up ->
#         if current_floor == @max_floor do
#           direction = :down
#           target_floor = @max_floor - 1
#         else
#           target_floor = current_floor + 1
#           direction = :up
#         end

#       :down ->
#         if current_floor == @min_floor do
#           direction = :up
#           target_floor = @min_floor + 1
#         else
#           target_floor = current_floor - 1
#           direction = :down
#         end

#       :nil ->
#         IO.puts("Warning! Should be impossible to accheive this error when stationary")
#         Logger.error("Timeout for movement accheived when stationary")
#         :error
#       end

#     # Trying to restore the state by giving an order up or down
#     Logger.info("Trying to restore movement in direction #{direction} with order to floor #{target_floor}")

#     # Setting the next order and direction
#     #data.order = target_floor # Need to find a way to do this
#     #data.dir = direction

#     {:reply, {:ok, :resolving_motor_error}, data}
#   end


#   @doc """
#   @brief Function to solve if stop-button pressed
#   """
#   def handle_call(:stop_activated, _from,
#         %ElevatorData{state: :emergency} = data) do

#     # Must set the cost of the elevator to infty as long as it is in this state

#     # Must wait until the stop-button is dropped again
#     {:noreply, {:ok, :resolving_stop_error}, data}

#   end


#   @doc """
#   @brief Function to handle all other emergency-cases
#   """
#   def handle_call(_, _from,
#         %ElevatorData{state: :emergency} = data) do

#     # Must set the cost of the elevator to infty as long as it is in this state

#     # Should pherhaps just throw an error such that the elevator can be inited again
#     #data.state = :init # Same here...
#     #{:reply, {:error, :init}, data}

#   end

# end


# defmodule ElevatorDoor do
#   @moduledoc """

#   """

#   use GenServer

#   require ElevatorData

#   @timer_door             3000                # Timer for door                            [ms]


# end
