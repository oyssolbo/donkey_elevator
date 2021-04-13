defmodule LightsTest do

  require Logger
  require Lights

  defp init()
  do
    Driver.start_link([])
    Process.sleep(50)
    Lights.start_link([])
    Process.sleep(250)
  end

  def floorlight()
  do
    # Test passed

    init()

    Logger.info("Setting floorlight on floor 1")
    Lights.floorlight(1)
    Process.sleep(2000)

    Logger.info("Setting floorlight on floor 2")
    Lights.floorlight(2)
    Process.sleep(2000)

    Logger.info("Setting floor light on floor 4 - should throw an error")
    Lights.floorlight(4)
    Process.sleep(2000)
  end

  def doorlight()
  do
    # Test passed

    init()

    Logger.info("Opening door")
    Lights.doorlight(:on)

    Process.sleep(3000)

    Logger.info("Closing door")
    Lights.doorlight(:off)
  end

  def orderlights()
  do
    init()

    Process.sleep(500)

    order1 =
      %Order{
        delegated_elevator: nil,
        order_floor: 0,
        order_id: make_ref(),
        order_type: :hall_up
      }

    order2 =
      %Order{
        delegated_elevator: nil,
        order_floor: 2,
        order_id: make_ref(),
        order_type: :hall_up
      }

    order3 =
      %Order{
        delegated_elevator: nil,
        order_floor: 0,
        order_id: make_ref(),
        order_type: :hall_down
      }

    order4 =
      %Order{
        delegated_elevator: nil,
        order_floor: 1,
        order_id: make_ref(),
        order_type: :hall_down
      }


    orders_set = [order1, order2, order3, order4]

    orders_clear = [order1, order2]

    Lights.order_lights_set(orders_set)

    Process.sleep(2000)

    Logger.info("Clearing some lights")

    Lights.order_lights_clear(orders_clear)
    Process.sleep(2000)

    #Logger.info("Trying to clear all lights")
    #Lights.clear_all_lights()
  end


end
