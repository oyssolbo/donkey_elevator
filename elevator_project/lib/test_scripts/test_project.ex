defmodule ProjectTest do

  require Logger

  require Driver
  require Network
  require Master
  require Elevator
  require Panel
  require Order

  defp start()
  do
    Logger.info("Starting linking to modules")

    Driver.start_link([])
    Panel.init()
    Master.start_link([])
    Elevator.start_link([])

    Logger.info("Modules linked")
  end

  def test_add_order()
  do
    start()

    Process.sleep(2000)

    Logger.info("Trying to add orders to master")
    order1 = Order.create_rnd_order()
    order2 = Order.create_rnd_order()

    Network.send_data_all_nodes(:panel, :master, {:panel_received_order, [order1, order2]})

    Logger.info("Orders sent to master")
  end

end
