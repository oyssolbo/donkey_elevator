defmodule Order do
  @moduledoc """
  Module that implements 'Orders' and includes a function to zip multiple orders into a
  list. This makes it easier to send
  """

  @min_floor Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1


  defstruct [
    order_id: :nil,
    order_type: :nil,
    order_floor: :nil,
    delegated_elevator: :nil
  ]


  @doc """
  Zips multiple orders into a list

  order_ids           List of each order's ID. For example time the order is given
  order_types         List of each order's type; :up, :down, :cab
  order_floors        List of each order's floor; 0, 1, 2, 3, ...
  delegated_elevators List of elevator delegated to serve each order

  Example
    l1 = [make_ref(), make_ref()]
    l2 = [:up, :down]
    l3 = [1, 4]
    l4 = [1, 2]

    orders = Order.zip(l1, l2, l3, l4)
  """
  def zip(
        order_ids,
        order_types,
        order_floors,
        delegated_elevators)
  do
    zip(order_ids, order_types, order_floors, delegated_elevators, [])
  end

  defp zip(
        [order_id | rest_id],
        [order_type | rest_types],
        [order_floor | rest_floors],
        [order_delegated | rest_delegated],
        orders)
  do
    zip(rest_id, rest_types, rest_floors, rest_delegated,
    [
      %Order{
        order_id: order_id,
        order_type: order_type,
        order_floor: order_floor,
        delegated_elevator: order_delegated
      } | orders
    ])
  end

  defp zip(_, _, _, _, orders) do
    :lists.reverse(orders)
  end


  @doc """
  Function to check if an order is valid

  For the order to be valid, we require that:
    - order_floor is between min and max
    - order_type is either :cab, :up, :down
  """
  def check_valid_orders([order | rest_orders])
  do
    case check_valid_order(order) do
      :ok->
        check_valid_orders(rest_orders)
      {:error, id}->
        IO.puts("Invalid order found! Order's ID given as")
        IO.inspect(id)
        :error
    end
  end

  def check_valid_orders([])
  do
    :ok
  end

  defp check_valid_order(%Order{order_id: id, order_type: type, order_floor: floor} = _order)
  do

    if floor < @min_floor or floor > @max_floor do
      IO.puts("Order floor out of range. Received the floor")
      IO.inspect(floor)
      {:error, id}
    end

    if type not in [:cab, :up, :down] do
      IO.puts("Order invalid type. Received the type")
      IO.inspect(type)
      {:error, id}
    end

    :ok
  end


  @doc """
  Function to get all orders at floor 'floor' in a list of orders
  that satisfies the required [:dir, :cab]

  [order | rest_orders] List of orders to check
  floor                 Floor to check on
  dir                   Direction (:up, :down) to check for

  Returns               If
  list_of_orders        There are orders satisfying the requirements
  []                    No orders satisfies the requirements
  """
  def get_order_at_floor(
        [order | rest_orders],
        floor,
        dir)
  do
    order_floor = Map.get(order, :order_floor)
    order_dir = Map.get(order, :order_type)

    if order_dir in [dir, :cab] and order_floor == floor do
      [order | get_order_at_floor(rest_orders, floor, dir)]
    else
      get_order_at_floor(rest_orders, floor, dir)
    end
  end

  def get_order_at_floor(
        [],
        _floor,
        _dir)
  do
    []
  end


  @doc """
  Function to check if there are orders on floor 'floor' with the
  direction 'dir' or ':cab'

  orders  List of orders to check
  floor   Floor to check on
  dir     Direction (:up, :down) to check for

  Returns                   If
  {:true, list_of_orders}   There are orders satisfying the requirements
  {:false, []}              No orders satisfies the requirements
  """
  def check_orders_at_floor(
    orders,
    floor,
    dir)
  do
    satisfying_orders = get_order_at_floor(orders, floor, dir)

    if satisfying_orders == [] do
      {:false, []}
    else
      {:true, satisfying_orders}
    end
  end


  @doc """
  Function to remove all orders from the list with the current floor and direction

  first_order First order in the order-list
  rest_orders Rest of the orders in the order-list
  dir Direction of elevator
  floor Current floor the elevator is in

  Returns
  updated_orders List of orders where the old ones are deleted
  """
  def remove_orders(
        [%Order{order_type: order_type, order_floor: order_floor} = first_order | rest_orders],
        dir,
        floor)
  do
    if order_type not in [dir, :cab] or order_floor != floor do
      [first_order | remove_orders(rest_orders, dir, floor)]
    else
      remove_orders(rest_orders, dir, floor)
    end
  end

  def remove_orders(
        [],
        _dir,
        _floor)
  do
    []
  end


  @doc """
  Function to add a list of orders to another list of orders
  """
  def add_order_list_to_list(
        [order | rest_orders],
        list)
  do
    updated_list = add_order(order, list)
    add_order_list_to_list(rest_orders, updated_list)
  end

  def add_order_list_to_list(
        [],
        list)
  do
    list
  end


  @doc """
  Function to add a single order to a list 'list'
  """
  def add_order(
        new_order,
        list)
  do
    cond do
      list == []->
        [new_order]
      new_order in list->
        list
      new_order not in list->
        [list | new_order]
    end
  end
end
