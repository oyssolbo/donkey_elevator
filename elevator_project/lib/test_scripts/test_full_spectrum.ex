defmodule FST do
    require Logger

    require Driver
    require Network
    require Master
    require Elevator
    require Panel
    require Order

    def init(portnum) do
        try do
            Network.init_node_network()
            Driver.start_link([{127,0,0,1},portnum])
            Panel.start_link([])
            Master.start_link([])
            Elevator.start_link([])

            Logger.info("Full spectrum test suite initiated")
        catch
            :exit, _reason ->
                Logger.error("Could not initialize system")
        end
    end

end