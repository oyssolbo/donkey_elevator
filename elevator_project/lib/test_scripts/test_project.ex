defmodule ProjectTest do

  require Logger

  require Driver
  require Network
  require Master
  require Elevator
  require Panel
  require Order

  def start()
  do
    Logger.info("Starting linking to modules")

    Network.init_node_network()

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


  def test_multiple_masters()
  do
    Network.init_node_network()

    spawn(fn -> Master.start_link([]) end)
    Process.sleep(150)
    spawn(fn -> Master.start_link([]) end)

  end


  def test_order()
  do
    Driver.start_link([])
    Elevator.start_link([])
    Process.sleep(2000)

    Order.create_rnd_order() |>
      IO.inspect() |>
      Elevator.send_order_to_elevator()

    Order.create_rnd_order() |>
    IO.inspect() |>
    Elevator.send_order_to_elevator()

    Order.create_rnd_order() |>
    IO.inspect() |>
    Elevator.send_order_to_elevator()

    Order.create_rnd_order() |>
      IO.inspect() |>
      Elevator.send_order_to_elevator()

    Order.create_rnd_order() |>
    IO.inspect() |>
    Elevator.send_order_to_elevator()
  end


  def init_all()
  do
    Network.init_node_network()
    Driver.start_link([])
    Elevator.start_link([])
    Master.start_link([])
    Panel.start_link([])
    Lights.start_link([])
  end

end
