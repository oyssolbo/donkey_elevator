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

  require Master
  require Logger
  require Order
  require Client
  require Elevator

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


  def send_master_struct()
  do
    # Test passed

    Master.start_link([])
    Process.sleep(500)

    opts = [
      active_order_list:        [Order.create_rnd_order()],
      master_message_id:        69,
      activation_time:          Timer.get_utc_time()
    ]

    master_struct = struct(Master, opts)
    Process.sleep(500)

    Logger.info("Sending master struct")
    Master.send_master_struct(master_struct)
    Logger.info("Master struct sent")
    Process.sleep(1000)
  end

  def test_two_active_masters()
  do
    # Test passed

    activation_time0 = Timer.get_utc_time()
    master_struct0 = struct(Master, [activation_time: activation_time0, master_message_id: 69, master_timer: make_ref()])
    Logger.info("Starting master and testing in backup")
    Master.start_link([])
    Process.sleep(100)
    Master.test_backup_receive(master_struct0)
    Process.sleep(1000)


    activation_time1 = Timer.get_utc_time()
    master_struct1 = struct(Master, [activation_time: activation_time1, master_message_id: 1, master_timer: make_ref()])
    activation_time4 = Timer.get_utc_time()
    master_struct4 = struct(Master, [activation_time: activation_time1, master_message_id: 5, master_timer: make_ref()])
    Process.sleep(50)

    activation_time2 = Timer.get_utc_time()
    master_struct2 = struct(Master, [activation_time: activation_time2, master_message_id: 2, master_timer: make_ref()])

    Logger.info("Testing first master youngest")
    Master.modify_master(:active_state, master_struct1)
    Master.test_multiple_active(master_struct2)

    Logger.info("Testing state")
    Master.get_state()

    Logger.info("Testing both master at the same age")

    master_struct3 = struct(Master, [activation_time: activation_time1, master_message_id: 2, master_timer: make_ref()])

    Master.modify_master(:active_state, master_struct1)
    Master.test_multiple_active(master_struct3)

    Logger.info("Testing state")
    Master.get_state()

    Logger.info("Test first master oldest")
    Master.modify_master(:active_state, master_struct2)
    Master.test_multiple_active(master_struct4)

    Logger.info("Testing state")
    Master.get_state()

  end


  ##### Debugging functions originally inside master.ex #####

  def test_backup_receive(extern_master_data)
  do
    GenStateMachine.cast(@node_name, {:master_update_active, extern_master_data})
  end

  def modify_master(
        state,
        master_data)
  do
    GenStateMachine.cast(@node_name, {:modify_master, state, master_data})
  end

  def get_state()
  do
    GenStateMachine.cast(@node_name, :get_state)
  end

  def handle_event(
        :cast,
        :get_state,
        state,
        master_data)
  do
    Logger.info("Current state")
    IO.inspect(state)
    Process.sleep(100)
    {:next_state, state, master_data}
  end

  def handle_event(
        :cast,
        {:modify_master, new_state, new_master_data},
        _old_state,
        _old_master_data)
  do
    Logger.info("Modified master data")
    Process.sleep(100)
    {:next_state, new_state, new_master_data}
  end

  def test_multiple_active(extern_master_data)
  do
    GenStateMachine.cast(@node_name, {:master_update_active, extern_master_data})
  end


end
