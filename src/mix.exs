defmodule Elevator.MixProject do
  use Mix.Project

  def project do
    [
      app: :elevator,
      version: "0.1.0",
      elixir: "1.3.3",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ElevatorProject.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      { :fsmx, "~> 0.3.0" },
      { :dep_from_git, git: "https://github.com/subvisual/fsmx", tag: "0.3.0" },
      { :socket, "~> 0.3" },
      { :dep_from_git, git: "https://github.com/meh/elixir-socket.git", tag: "0.3.0" }
    ]
  end
end
