defmodule ElevatorTest do

  require Logger
  require Elevator
  require Order

  def test_elevator_init()
  do
    Elevator.start_link()
    Process.sleep(500)
  end

  def test_elevator_init_to_idle()
  do
    test_elevator_init()
    Elevator.check_at_floor(1)
    Process.sleep(500)
  end

  def test_elevator_idle_to_moving()
  do
    # The elevator does not transition from idle to moving (order not registered)
    test_elevator_init_to_idle()
    opts = [order_id: make_ref(), order_type: :cab, order_floor: 2]
    order = struct(Order, opts)
    Elevator.delegate_order(order)
    Elevator.check_at_floor(1)
    Process.sleep(100)
    Elevator.check_at_floor(1)
    Process.sleep(500)
  end

  def test_elevator_moving_to_door()
  do
    test_elevator_idle_to_moving()
    Elevator.check_at_floor(2)
    Process.sleep(500)
  end

  def test_engine_failure()
  do
    test_elevator_idle_to_moving()
    Elevator.check_at_floor(1)
    Process.sleep(2000)
    Elevator.check_at_floor(1)
    Process.sleep(2000)
    Elevator.check_at_floor(1)
    Process.sleep(2000)
    Elevator.check_at_floor(2)
    Process.sleep(2000)
  end


  def test_while()
  do
    Stream.iterate(0, &(&1+1)) |> Enum.reduce_while(0, fn i, acc ->
      IO.inspect(i)
      {:cont, acc + 1}
    end)
  end


  def test_optimal_floor()
  do
    opts1 = [order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    dir1 = :down
    floor = 2

    # Optimal floor should be floor 2
    #opt_floor_test_1 = Elevator.calculate_optimal_floor([order1, order2], dir1, floor)
    #IO.puts("Optimal should be 2")
    #IO.inspect(opt_floor_test_1)
    #IO.puts(" WHAT?? ")

    #dir2 = :up
    # Optimal floor should be floor 3
    #opt_floor_test_2 = Elevator.calculate_optimal_floor([order1, order2], dir2, floor)
    #IO.puts("Optimal should be 3")
    #IO.inspect(opt_floor_test_2)

    # Optimal floor should be floor 3
    opt_floor_test_3 = Elevator.calculate_optimal_floor([order2], dir1, floor)
    #IO.puts("Optimal should be 3")
    #IO.inspect(opt_floor_test_3)
  end


  def test_optimal_direction()
  do
    opts1 = [order_id: make_ref(), order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_id: make_ref(), order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    dir1 = :down
    floor = 2

    # Optimal dir should be :down
    opt_dir_test_1 = Elevator.calculate_optimal_direction([order1, order2], dir1, floor)
    IO.puts("Optimal should be :down")
    IO.inspect(opt_dir_test_1)

    dir2 = :up
    # Optimal dir should be :up
    opt_dir_test_2 = Elevator.calculate_optimal_direction([order1, order2], dir2, floor)
    IO.puts("Optimal should be :up")
    IO.inspect(opt_dir_test_2)

    # Optimal dir should be :up
    opt_dir_test_3 = Elevator.calculate_optimal_direction([order2], dir1, floor)
    IO.puts("Optimal should be :up")
    IO.inspect(opt_dir_test_3)

  end

  def test_get_order_at_floor()
  do
    opts1 = [order_id: make_ref(), order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_id: make_ref(), order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    order_floor_1_down = Order.get_order_at_floor([order1, order2], 1, :down)
    IO.puts("Orders at floor 1 going down")
    IO.inspect(order_floor_1_down)

    order_floor_1_up = Order.get_order_at_floor([order1, order2], 1, :up)
    IO.puts("Orders at floor 1 going up")
    IO.inspect(order_floor_1_up)

    order_floor_3_down = Order.get_order_at_floor([order1, order2], 3, :down)
    IO.puts("Orders at floor 3 going down")
    IO.inspect(order_floor_3_down)

    order_floor_3_up = Order.get_order_at_floor([order1, order2], 3, :up)
    IO.puts("Orders at floor 3 going up")
    IO.inspect(order_floor_3_up)


    IO.puts("Checking orders at floor")

  end


  def test_check_order_at_floor()
  do
    opts1 = [order_type: :up, order_floor: 1]
    order1 = struct(Order, opts1)

    opts2 = [order_type: :down, order_floor: 3]
    order2 = struct(Order, opts2)

    dir = :down

    {bool, order} = Order.check_orders_at_floor([order1, order2], 1, :up)
    case {bool, dir} do
      {:true, _} ->
        IO.puts("OK")
      {:false, :up} ->
        IO.puts("Not OK - up")
      {:false, :down} ->
        IO.puts("Not OK - down")
    end
  end

  def test_received_order()
  do
    test_elevator_init_to_idle()

    opts = [order_type: :up, order_floor: 2]
    order = struct(Order, opts)

    Elevator.check_at_floor(1)

    #Logger.info("Done check elevator at floor")
    Process.sleep(100)

    Logger.info("Starting delegating to elevator")
    Elevator.delegate_order(order)
    Logger.info("Done delegating to elevator")

    Process.sleep(50)

    #Logger.info("Check elevator at floor")
    #Elevator.check_at_floor(1)
    Process.sleep(100)

    #Elevator.check_at_floor(2)
    Process.sleep(500)
  end


end
