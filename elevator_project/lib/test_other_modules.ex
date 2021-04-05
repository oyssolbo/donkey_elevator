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

end
