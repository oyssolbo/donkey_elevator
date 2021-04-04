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

  def test_master_backup_to_active()
  do
    # Test passed

    Master.start_link()
    Process.sleep(2500)
  end

  def test_give_active_orders()
  do
    # Test passed

    test_master_backup_to_active()

    order_opts1 = [order_id: Timer.get_utc_time(), order_type: :down, order_floor: 2]
    order1 = struct(Order, order_opts1)

    order_opts2 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3]
    order2 = struct(Order, order_opts2)

    Master.give_master_orders([order1, order2])
  end


  def test_find_optimal_elevator()
  do
    # Test passed

    order_opts = [order_id: Timer.get_utc_time(), order_type: :down, order_floor: 2]
    order = struct(Order, order_opts)

    elevator_id1 = Timer.get_utc_time()

    elevator_data1 = %{dir: :down, last_floor: 3, elevator_id: elevator_id1}
    elevator_client1 = struct(Client, [client_data: elevator_data1])


    elevator_id2 = Timer.get_utc_time()

    elevator_data2 = %{dir: :up, last_floor: 2, elevator_id: elevator_id2}
    elevator_client2 = struct(Client, [client_data: elevator_data2])

    id = Master.find_optimal_elevator(order, [elevator_client1, elevator_client2], struct(Client))

    IO.puts("Optimal id should be")
    IO.inspect(elevator_id1)

    IO.puts("Found id, is")
    IO.inspect(id)
  end


  def test_empty_optimal_elevator()
  do
    # Test passed

    order_opts = [order_id: Timer.get_utc_time(), order_type: :down, order_floor: 2]
    order = struct(Order, order_opts)

    id = Master.find_optimal_elevator(order, [], struct(Client))
  end

  def test_combine()
  do
    # Test passed

    order_opts1 = [order_id: Timer.get_utc_time(), order_type: :down, order_floor: 2]
    order1 = struct(Order, order_opts1)
    Process.sleep(10)

    order_opts2 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3]
    order2 = struct(Order, order_opts2)
    Process.sleep(10)

    order_opts3 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3, delegated_elevator: Timer.get_utc_time()]
    order3 = struct(Order, order_opts3)

    master_orders1 = [order1, order2]
    master_struct1 = struct(Master, [active_order_list: master_orders1, master_message_id: 69])

    master_orders2 = [order3]
    master_struct2 = struct(Master, [active_order_list: master_orders2, master_message_id: 420])

    Master.combine_master_data_struct(master_struct1, master_struct2)

  end

  def test_get_undelegated_orders()
  do
    # Test passed

    order_opts1 = [order_id: Timer.get_utc_time(), order_type: :down, order_floor: 2]
    order1 = struct(Order, order_opts1)
    Process.sleep(10)

    order_opts2 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3]
    order2 = struct(Order, order_opts2)
    Process.sleep(10)

    order_opts3 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3, delegated_elevator: Timer.get_utc_time()]
    order3 = struct(Order, order_opts3)
    Process.sleep(10)

    Master.get_undelegated_orders(struct(Master, [active_order_list: order1]), [order1, order2, order3])
  end


  def test_delegate_orders()
  do
    # Test passed

    elevator_id1 = Timer.get_utc_time()
    elevator_data1 = %{dir: :down, last_floor: 3}
    elevator_client1 = struct(Client, [client_data: elevator_data1, client_id: elevator_id1])

    elevator_id2 = Timer.get_utc_time()
    elevator_data2 = %{dir: :up, last_floor: 2}
    elevator_client2 = struct(Client, [client_data: elevator_data2, client_id: elevator_id2])

    order_opts1 = [order_id: Timer.get_utc_time(), order_type: :down, order_floor: 2]
    order1 = struct(Order, order_opts1)

    order_opts2 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3]
    order2 = struct(Order, order_opts2)

    IO.puts("First should be delivered to")
    IO.inspect(elevator_id1)

    IO.puts("Second should be delivered to")
    IO.inspect(elevator_id2)

    delegated_orders = Master.delegate_orders([order1, order2], [elevator_client1, elevator_client2])
  end

  def test_remove_floor_orders()
  do
    order_opts1 = [order_id: Timer.get_utc_time(), order_type: :down, order_floor: 2]
    order1 = struct(Order, order_opts1)
    Process.sleep(10)

    order_opts2 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3]
    order2 = struct(Order, order_opts2)
    Process.sleep(10)

    order_opts3 = [order_id: Timer.get_utc_time(), order_type: :up, order_floor: 3, delegated_elevator: Timer.get_utc_time()]
    order3 = struct(Order, order_opts3)

    Order.remove_orders([order1], [order1, order2, order3])
  end

end
