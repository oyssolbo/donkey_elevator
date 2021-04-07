defmodule Elevator.Supervisor do
  @moduledoc """
  Supervisor for the elevator. Restarts the module if a bug or something
  else causes it to crash.

  It is a one-to-one relationship between the elevator and the supervisor
  """

  use Supervisor


  @doc """
  Starts a link from the supervisor to the module
  """
  def start_link(init_arg)
  do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end


  @doc """
  Function for initializing the supervisor and 'children' (child = elevator)
  """
  @impl :true
  def init(_init_arg)
  do
    children = [
      {Elevator, []}
    ]

    # one_for_one: Only one module will be spawned at crash
    # max_seconds: Number of seconds we allow max_restarts to occur.
    #               Defaults to 5
    # max_restarts: Number of restarts we allow within max_seconds.
    #               Defaults to 3
    opts = [
      strategy: :one_for_one,
      max_seconds: 2,
      name: :elevator_supervisor
    ]
    Supervisor.init(children, opts)
  end
end
