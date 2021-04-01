defmodule MasterTest do
  @moduledoc """
  Module for testing master

  Desired tests:
    - Calculating optimal elevator to serve an order
    - Calculating cost for an elevator/order
    - Getting undelegated orders
    - Getting orders that are previously set delegated to an elevator if the elevator 'times out'
    - Transitions from backup to acktive


    Requires network:
    - Testing if two masters are active simultaneously
    - Communication between an elevator and a master (send status etc.)
  """

  def test_find_optimal_elevator()
  do
    order_opts = [order_id: Timer.get_utc_time(), order_type: :cab, order_floor: 2]
    order = struct(Order, order_opts)

    elevator_id = Timer.get_utc_time()

    elevator_data = %{dir: :down, last_floor: 3, elevator_id: elevator_id}
    elevator_client = struct(Client, [client_data: elevator_data])

    id = Master.find_optimal_elevator(order, elevator_client, struct(Client))
  end



end
