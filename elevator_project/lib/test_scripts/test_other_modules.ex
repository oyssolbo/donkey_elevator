defmodule ClientTest do

  require Timer
  require Client
  require Logger

  def test_add_clients()
  do
    # Test passed

    empty_list = []
    client1 = struct(Client, [client_data: 1, client_id: 1])
    client2 = struct(Client, [client_data: 2, client_id: 2])
    client3 = struct(Client, [client_data: 3, client_id: 3])

    client_list1 = Client.add_clients(client1, empty_list)
    client_list2 = Client.add_clients([client2, client3], client_list1)

    IO.puts("Client list 1")
    IO.inspect(client_list1)

    IO.puts("Client list 2")
    IO.inspect(client_list2)

    Process.sleep(10)
    {client_list1, client_list2, client3}
  end

  def test_remove_clients()
  do
    # Test passed

    _client1 = struct(Client, [client_data: 1, client_id: 1])
    client2 = struct(Client, [client_data: 2, client_id: 2])
    _client3 = struct(Client, [client_data: 3, client_id: 3])

    {_client_list1, client_list2, client4} = test_add_clients()

    IO.puts("Original client-list2")
    IO.inspect(client_list2)

    IO.puts("'Removed' client-list2")
    Client.remove_clients(client2, client_list2) |> IO.inspect()

    IO.puts("Actually removed client-list2")
    Client.remove_clients(client4, client_list2) |> IO.inspect()
  end

  def test_modify_client_field()
  do
    # Test passed

    client1 = struct(Client, [client_data: 1, client_id: 1])
    client2 = struct(Client, [client_data: 2, client_id: 2])
    client3 = struct(Client, [client_data: 3, client_id: 3])

    client_list = [client1, client2, client3]

    Client.modify_client_field(client_list, :client_id, 69) |> IO.inspect()
  end

  def test_extract_client()
  do
    # Test passed

    client1 = struct(Client, [client_data: 1, client_id: 1])
    client2 = struct(Client, [client_data: 2, client_id: 2])
    client3 = struct(Client, [client_data: 3, client_id: 3])

    client_list = [client1, client2, client3]

    Client.extract_client(1, client_list) |> IO.inspect()
  end


  def test_clients()
  do

  elevator_id1 = Timer.get_utc_time()
  dir1 = :up
  last_floor1 = 1

  elevator_id2 = Timer.get_utc_time()
  dir2 = :down
  last_floor2 = 3


  Logger.info("Adding client 1")

  old_elevator_client_list = []
  elevator_client1 =
    case Client.extract_client(elevator_id1, old_elevator_client_list) do
      [] ->
        Logger.info("Client 1 does not exist")
        struct(Client,
          [
            client_id: elevator_id1,
            client_data: %{dir: dir1, last_floor: last_floor1},
            client_timer: make_ref()
          ])
      [old_client] ->
        Logger.info("Client 1 exists")
        Map.put(old_client, :client_data, %{dir: dir1, last_floor: last_floor1})
    end

  updated_elevator_list1 =
    Timer.start_timer(self(), elevator_client1, :client_timer, :elevator_timeout, 100) |>
    Client.add_clients(old_elevator_client_list)

  Logger.info("Client-list after adding 1")
  IO.inspect(updated_elevator_list1)


  Logger.info("Adding client 2")

  elevator_client2 =
    case Client.extract_client(elevator_id2, updated_elevator_list1) do
      [] ->
        Logger.info("Client 2 does not exist")
        struct(Client,
          [
            client_id: elevator_id2,
            client_data: %{dir: dir2, last_floor: last_floor2},
            client_timer: make_ref()
          ])
      [old_client] ->
        Logger.info("Client 2 exists")
        Map.put(old_client, :client_data, %{dir: dir2, last_floor: last_floor2})
    end

  updated_elevator_list2 =
    Timer.start_timer(self(), elevator_client2, :client_timer, :elevator_timeout, 1000) |>
    Client.add_clients(updated_elevator_list1)

  Logger.info("Client-list after adding 2")
  IO.inspect(updated_elevator_list2)


  Logger.info("Testing to add client 1 again")

  elevator_client3 =
    case Client.extract_client(elevator_id1, updated_elevator_list2) do
      [] ->
        Logger.info("Client 1 does not exist")
        struct(Client,
          [
            client_id: elevator_id1,
            client_data: %{dir: dir1, last_floor: last_floor1},
            client_timer: make_ref()
          ])
      [old_client] ->
        Logger.info("Client 1 exists")
        Map.put(old_client, :client_data, %{dir: dir1, last_floor: last_floor1})
    end

  updated_elevator_list3 =
    Timer.start_timer(self(), elevator_client3, :client_timer, :elevator_timeout, 1000) |>
    Client.add_clients(updated_elevator_list2)

  Logger.info("Client-list after adding 1 again")
  IO.inspect(updated_elevator_list3)


  end



end


defmodule OrderTest do

  require Timer
  require Order
  require Logger

  def test_add_order()
  do
    # Test passed

    order1 = Order.create_rnd_order()
    order2 = Order.create_rnd_order()
    order3 = Order.create_rnd_order()

    Logger.info("First test")
    Order.add_orders([order1, order2, order3], []) |> IO.inspect()

    Logger.info("Second test")
    Order.add_orders([order1, order2, order2], [order3, order1]) |> IO.inspect()
  end

  def test_extract_order()
  do
    # Test passed

    order1 = Order.create_rnd_order(0, :up)
    order2 = Order.create_rnd_order(1, :down)
    order3 = Order.create_rnd_order(1, :cab)

    Logger.info("First test")
    Order.extract_order(order1.order_id, [order1, order2, order3]) |> IO.inspect()

    Logger.info("Second test")
    Order.extract_orders(3, :down, [order1, order2, order3]) |> IO.inspect()

    Logger.info("Third test")
    Order.extract_orders(:cab, [order1, order2, order3]) |> IO.inspect()
  end


  def test_find_and_remove_empty()
  do
    # Test passed

    order1 = Order.create_rnd_order(0, :up)
    order2 = Order.create_rnd_order(1, :down)
    order3 = Order.create_rnd_order(1, :cab)

    test_order_id = 1

    order = Order.extract_orders(test_order_id, [order1, order2, order3])
    Order.remove_orders(order, [order1, order2, order3])

    #Enum.map([order], fn o -> Order.remove_orders(o, [order1, order2, order3]) end) |> IO.inspect()
  end


  def test_extract_list()
  do
    # Test passed

    order1 = Order.create_rnd_order(0, :up)
    order2 = Order.create_rnd_order(1, :down)
    order3 = Order.create_rnd_order(1, :cab)

    Order.extract_order([order1.order_id, order2.order_id], [order1, order2, order3])

    Order.extract_order([], [order1, order2, order3])
  end


  def test_remove_orders()
  do
    # Test passed

    order1 = Order.create_rnd_order(0, :up)
    order2 = Order.create_rnd_order(1, :down)
    order3 = Order.create_rnd_order(1, :cab)

    order_list = [order1, order2, order3]

    IO.puts("Test 1")
    {_order_at_floor1, floor_orders1} = Order.check_orders_at_floor(order_list, 1, :up)

    IO.inspect(floor_orders1)

    Order.remove_orders(floor_orders1, order_list) |> IO.inspect()

    IO.puts("Test 2")
    {_order_at_floor2, floor_orders2} = Order.check_orders_at_floor(order_list, 1, :down)

    Order.remove_orders(floor_orders2, order_list) |> IO.inspect()

    IO.puts("Test 3")
    order4 = Order.create_rnd_order(4, :cab)

    {_bool_, floor_orders3} = Order.check_orders_at_floor(order_list, 4, :up)

    IO.inspect(floor_orders3)
      |> Order.remove_orders(order_list)
      |> IO.inspect()

    IO.puts("Test 4")
    Order.remove_orders(order4, [])
    |> IO.inspect()

    :ok
  end


  def check_remove_duplicates()
  do
    # Test passed

    order1 = Order.create_rnd_order(0, :hall_up)#
    order2 = Order.create_rnd_order(1, :hall_down)#
    order3 = Order.create_rnd_order(1, :cab)#

    order4 = Order.create_rnd_order(0, :hall_up)
    order5 = Order.create_rnd_order(3, :hall_down)#
    order6 = Order.create_rnd_order(2, :cab)#
    order7 = Order.create_rnd_order(0, :hall_up)
    order8 = Order.create_rnd_order(0, :hall_up)
    order9 = Order.create_rnd_order(0, :hall_up)

    order_list1 = [order1, order2, order3]
    Order.check_and_remove_duplicates([order4, order5, order6, order7, order8, order9], order_list1) |> IO.inspect()
  end


end
