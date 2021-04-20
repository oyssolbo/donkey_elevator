# ElevatorProject

Repository maintaining terrible elixir-code for the elevator-project in TTK4145 - "Sanntidsprogrammering" - at NTNU, spring 2021.


## File-structure
The project's source code is found inside _/lib_, with the supervisors being inside _/lib/supervisors_. 

## Comunication
The modules comunicate between each other via message passing based on the function in the Network module.  
Master    <-> Master  
Master    <-> Panel  
Master    <-> Elevator  
Master     -> Lights  
Elevator   -> Panel  
Elevator   -> Lights  

The system is configured in a semi-peer-to-peer solution, set up in a way such that each machine has an instance of the following modules: 
```Master```, ```Elevator```, ```Panel``` and ```Lights```. These are consistent, concurrent processes, monitored by supervisors. 
Each machine is capable of operating its local elevator independently, via the four mentioned module instances. In the case where several 
machines are connected together, only the ```Master``` module will know, or care. They will then agree amongst themselves who will take on 
the role of 'active', and control the distribution of orders, and who will remain in a standby state - acting as backup, similar to the
configuration found in process-pairs.


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
This method is unstable and will not work on every elixir version. The method below should work on most elixir/elang installs.
```
epmd -daemon
mix deps.get
mix run
cd _build/dev/lib/elevator_project/ebin
iex
Network.init_node_network()
ElevatorProject.Application.start([], [])
```
This starts the supervision-tree, and enables all modules on the node

## External libraries used
- Poison 4.0.1 - Lightweight JSON library for Elixir. See documentation, https://hexdocs.pm/poison/Poison.html
- Genstatemachine - general statemachine built on top of genserver. Can be found here: https://hex.pm/packages/gen_state_machine


