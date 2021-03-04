defmodule Elevator.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_project,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      [applications: [:gen_state_machine], [:logger]]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:gen_state_machine, "~> 3.0"}]
  end
end
