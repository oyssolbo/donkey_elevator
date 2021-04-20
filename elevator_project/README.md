# ElevatorProject

Repository maintaining terrible elixir-code for the elevator-project in TTK4145 - "Sanntidsprogrammering" - at NTNU, spring 2021.

## Running the project

After cloning the workspace, check if the line
```
mod: {ElevatorProject.Application, []}
```
inside elevator_project/mix.exs is commented out or not. 
If the line is included (AKA _not_ commented out), the entire project can be built and runned using
```
mix deps.get
mix run
```
This method is unstable and not recommended, as the project currently uses default-parameters for Driver. Thus it is impossible to use multiple elevators on a single node. This means that most likely one or multiple fatal errors will occur, such that it is recommended to outcomment the line and build and run the project using
```
epmd -daemon
mix deps.get
mix run
cd _build/dev/lib/elevator_project/ebin
iex
Network.init_node_network()
Driver.start_link(port)
ElevatorProject.Application.start([], [])
```
This starts the supervision-tree, and enables all modules on the node. By corresponding the argument 'port' between the Simulator and the Driver, multiple elevators can be runned simultaneously

## File-structure
The project's source code is found inside _/lib_, with the supervisors being inside _/lib/supervisors_

