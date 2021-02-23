defmodule Elevator do
  @moduledoc """
  Module describing one single elevator in the elevator-project
  """

  """
  Required functions:

  Handlers:
    -input: order
    -input: obstruction
    -input: emergency

  Calculate next state given input:
    -

  Store input and next state before actually switching

  Change the system's state and deliver output

  Must also initialize the elevator when the state is lost
  """

  use GenServer

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
  defstruct [:state, :order, :floor, :dir, :timer]

  # Starting link to the GenServer
  def start_link(init_arg \\ []) do
    GenServer.start_link(__MODULE__, init_arg, name: @name)
  end

  # Initializing the elevator after startup
  def init_elevator(socket) do

    data = %Elevator{
      state: :init,
      order: :nil,
      floor: :nil,
      dir: :down,
      timer: make_ref()
    }

    # Potentially load last state from elevator. Must check
    # validity of that state. Check that we have a valid state
    # and valid data to work with - especially if we have to read
    # the last saved data from memory
    # previous_orders = access_orders(self()) # Accessing the orders for this elevator
    valid_data_check()


    # When correctness checked, change the state of HW
    Driver.set_door_open_light(:off)
    Driver.set_motor_direction(:down)

    # We must have a function that detects when we come to a floor, and
    # sets the elevator into the new state

    # Return if correct
    {:ok, data}
  end



  # Checking the validity of something
  defp valid_data_check(data) do
    :ok
  end


  # By using GenServer, we are allowed to overwrite the callback-functions

  # Handlers

  @doc """
  Get position of elevator during init
  """
  def handle_call(:get_position, _from, %Elevator{state: :init} = data) do
    {:reply, {:error, :not_ready}, data}
  end

  @doc """
  Return the elevator's position when at a floor
  """
  def handle_call(:get_position, _from, data) do
    {:reply, {:ok, data.floor}, data}
  end



  """
  Just for experimenting/thinking

  Problem is to understand how one can solve the problem with the state-machine
  """
  def receive_messages() do
    # Access internal data
    state = :nil # or something - however we can check this
    current_floor = :nil # or something

    # Running the process on its own thread via spawn(), such that we can receive data
    # from the outside world, like the master/delegator
    receive do
      # Receives f.ex. new orders from delegator
      {:new_order, order: order} ->
        IO.puts("Serving order #{order}")
        calculate_next_service(order)

      {:error, _} ->
          # What to do if an error occurs

    end




    # We would like to to this infinite
    fsm()

  end


  def fsm(messages, internal_states) do
    # This function is purely based on the input


    """
    But do we really need this when we already use GenServer?
    By using GenServer we already use CB-functions such that a FSM is
    constructed via the messages that is received from the external connections.

    In other words, by using a GenServer command, we can design the system such
    that it creates an abstracted FSM
    """

  end



end
