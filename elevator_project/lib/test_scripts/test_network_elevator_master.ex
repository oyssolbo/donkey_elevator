defmodule NetworkTest do

  # Should probably start init as a new process, will fix tomorrow
  def init()
  do
    Driver.start_link([])
    Network.init_node_network()
    #Elevator.start_link([])
    Master.start_link([])
    spawn( fn -> Panel.init() end)
  end



end
