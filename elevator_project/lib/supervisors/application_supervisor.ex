defmodule ElevatorProject.Supervisor do
  @moduledoc """
  Supervisor for the entire elevator-projects. Invokes all other supervisors, and
  restarts them if a fatal bug causes both the module and the supervisor to be
  killed
  """

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl :true
  def init(_args) do
    children = [
      #{Driver.Supervisor, []},
      {Elevator.Supervisor, []},
      {Master.Supervisor, []},
      {Panel.Supervisor, []},
      {Lights.Supervisor, []}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
