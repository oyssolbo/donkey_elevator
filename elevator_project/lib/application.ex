defmodule ElevatorProject.Application do
  @moduledoc """
  Entry-point of the elevator-projects. Starts the modules' supervisors,
  which then again invokes the modules
  """

  use Application

  @doc """
  Function for spawning the entire elevator project. Spawns the major supervisor,
  which spawns the supervisors for Elevator, Master, ...
  """
  def start(_type, _args) do
    children = [
      {ElevatorProject.Supervisor, []}
    ]

    opts = [
      strategy: :one_for_one,
      name: ElevatorProject.Supervisor
    ]
    Supervisor.start_link(children, opts)
  end



end
