defmodule Order do
  @moduledoc """
  Module that implements the struct 'Order' with different functions for operating
  on them
  """

  @min_floor Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1


  defstruct [
    order_id: :nil,
    order_type: :nil,
    order_floor: :nil,
    delegated_elevator: :nil
  ]

## Add/remove orders from list ##
  @doc """
  Function to remove all orders from the list with the current floor and direction

  first_order First order in the order-list
  rest_orders Rest of the orders in the order-list
  dir Direction of elevator
  floor Current floor the elevator is in

  Returns
  updated_orders List of orders where the old ones are deleted
  """
  def remove_floor_orders(
          [_first_order | _rest_orders] = orders,
          dir,
          floor)
  do
    orders_at_floor = get_orders_with_value(orders, :order_floor, floor)

    order_in_dir = get_orders_with_value(orders_at_floor, :order_type, dir)
    order_in_cab = get_orders_with_value(orders_at_floor, :order_type, :cab)

    temp_orders = remove_orders(order_in_dir, orders)
    remove_orders(order_in_cab, temp_orders)

  #       [%Order{order_type: order_type, order_floor: order_floor} = first_order | rest_orders],
  #       dir,
  #       floor)
  # do
  #   if order_type not in [dir, :cab] or order_floor != floor do
  #     [first_order | remove_floor_orders(rest_orders, dir, floor)]
  #   else
  #     List.delete(list, first_order) |>
  #       remove_floor_orders(dir, floor)
  #     # remove_floor_orders(rest_orders, dir, floor)
  #   end
  end


  @doc """
  Function that removes a single order from a list of orders

  The function searches through the entire list, such that if a duplicated
  order has occured, both are then removed
  """
  def remove_orders(
        order,
        order_list)
  when order |> is_struct()
  do
    original_length = length(order_list)
    new_list = List.delete(order_list, order)
    new_length = length(new_list)

    case new_length < original_length do
      :true->
        remove_orders(order, new_list)
      :false->
        new_list
    end
  end

  @doc """
  Function to remove a list of orders from another list of orders

  It is assumed that there is only one copy of each order in the list
  """
  def remove_orders(
        [order | rest_orders],
        order_list)
  do
    new_list = remove_orders(order, order_list)
    remove_orders(rest_orders, new_list)
  end

  def remove_orders(
        [],
        order_list)
  do
    order_list
  end

  @doc """
  Function to add a single order to a list of orders
  """
  def add_orders(
        order,
        order_list)
  when order |> is_struct()
  do
    order_id = Map.get(order, :order_id)

    original_order = get_orders_with_value(order_list, :order_id, order_id)
    cond do
      order_list == []->
        [order]

      original_order != []->
        # An order with 'order_id' exists in order_list
        order_list

      original_order == []->
        [order_list | order]
    end
  end


  @doc """
  Function to add a list of orders to another list of orders.

  """
  def add_orders(
        [order | rest_orders],
        order_list)
  do
    [add_orders(order, order_list) | add_orders(rest_orders, order_list)]
  end

  def add_orders(
        [],
        order_list)
  do
    order_list
  end


## Valid orders ##
  @doc """
  Function to check if an order is valid. Invalid orders should not occur!

  If this function causes a crash, it is likely that an order is set to
  default (:nil)

  For the order to be valid, we require that:
    - order_floor is between min and max
    - order_type is either :cab, :up, :down
  """
  def check_valid_order(order)
  when order |> is_struct()
  do
    floor = Map.get(order, :order_floor)
    type = Map.get(order, :order_type)
    cond do
      floor < @min_floor->
        IO.puts("Invalid floor. Less than min-floor and at floor")
        IO.inspect(floor)
        :error
      floor > @max_floor->
        IO.puts("Invalid floor. Greater than max-floor and at floor")
        IO.inspect(floor)
        :error
      type not in [:cab, :up, :down]->
        IO.puts("Invalid type. Order has the type")
        IO.inspect(type)
        :error
      :true->
        :ok
    end
  end


  def check_valid_order([order | rest_orders])
  do
    case check_valid_order(order) do
      :ok->
        check_valid_order(rest_orders)
      :error->
        IO.puts("Invalid order found!")
        :error
    end
  end

  def check_valid_order([])
  do
    :ok
  end


## Orders at floor ##
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
  def get_orders_at_floor(
        [order | rest_orders],
        floor,
        dir)
  do
    order_floor = Map.get(order, :order_floor)
    order_dir = Map.get(order, :order_type)

    if order_dir in [dir, :cab] and order_floor == floor do
      [order | get_orders_at_floor(rest_orders, floor, dir)]
    else
      get_orders_at_floor(rest_orders, floor, dir)
    end
  end

  def get_orders_at_floor(
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
    satisfying_orders = get_orders_at_floor(orders, floor, dir)

    if satisfying_orders == [] do
      {:false, []}
    else
      {:true, satisfying_orders}
    end
  end


## Get spesific orders ##
  @doc """
  Find the orders in a list which have desired value 'value' in field
  'field'

  Ex.
    Find all of the orders assigned to elevator 1

  Returns a list of orders with the desired value in the field
  """
  def get_orders_with_value(
        [order | rest_orders],
        field,
        value)
  do
    order_value = Map.get(order, field)
    if order_value == value do
      [order | get_orders_with_value(rest_orders, field, value)]
    else
      get_orders_with_value(rest_orders, field, value)
    end
  end

  def get_orders_with_value(
        [],
        field,
        value)
  do
    []
  end


## Set spesific orders ##

  @doc """
  Assigns all of the orders to the elevator 'elevator_id'
  """
  def set_delegated_elevator(
        orders,
        elevator_id)
  do
    set_order_field(orders, :delegated_elevator, elevator_id)
  end


  @doc """
  Functions that gets all orders which are assigned to an elevator with the id
  'elevator_id'
  """
  def get_delegated_elevator(
        orders,
        elevator_id)
  do
    get_orders_with_value(orders, :delegated_elevator, elevator_id)
  end


  @doc """
  Function that sets the field of a single order
  """
  defp set_order_field(
        order,
        field,
        value)
  when order |> is_struct()
  do
    Map.put(order, field, value)
  end

  @doc """
  Sets the field 'field' in an order to an assigned 'value'

  Recurses over the entire list, such that all orders in the list get the
  desired 'value'

  Returns the new list
  """
  defp set_order_field(
        [order | rest_orders],
        field,
        value)
  do
    [set_order_field(order, field, value) | set_order_field(rest_orders, field, value)]
  end

  defp set_order_field(
        [],
        field,
        value)
  do
    []
  end

end
