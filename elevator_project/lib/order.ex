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
  Removes all orders from the list 'orders' on the floor 'floor' and in direction 'dir' or :cab
  """
  def remove_floor_orders(
          orders,
          dir,
          floor)
  do
    orders_at_floor = get_orders_with_value(orders, :order_floor, floor)

    order_in_dir = get_orders_with_value(orders_at_floor, :order_type, dir)
    order_in_cab = get_orders_with_value(orders_at_floor, :order_type, :cab)

    remove_orders(order_in_dir, orders) |>
      remove_orders(order_in_cab)
  end


  @doc """
  Function that removes a single order from a list of orders

  The function searches through the entire list, such that if a duplicated
  order has occured, all duplicates are removed
  """
  def remove_orders(
        %Order{} = order,
        order_list)
  when is_list(order_list)
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
  when is_list(order_list)
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
        %Order{} = order,
        order_list)
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
        new_orders,
        order_list)
  when is_list(order_list) and is_list(new_orders)
  do
    merge_order_lists(new_orders, order_list)
    # new_order_list = add_orders(new_orders, order_list)
    # add_orders(rest_orders, new_order_list)
    # [add_orders(order, order_list) | add_orders(rest_orders, order_list)]
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
  def check_valid_order(%Order{} = order)
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
      _->
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
        order_list,
        #[order | rest_orders],
        floor,
        dir)
  when is_list(order_list)
  do
    Enum.filter(order_list, fn x ->
      x.order_floor == floor and
      x.order_type in [dir, :cab]
    end)
    # order_floor = Map.get(order, :order_floor)
    # order_dir = Map.get(order, :order_type)

    # if order_dir in [dir, :cab] and order_floor == floor do
    #   [order | get_orders_at_floor(rest_orders, floor, dir)]
    # else
    #   get_orders_at_floor(rest_orders, floor, dir)
    # end
  end

  # def get_orders_at_floor(
  #       [],
  #       _floor,
  #       _dir)
  # do
  #   []
  # end


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

  def create_rnd_order()
  do
    rnd_id = Time.utc_now()
    rnd_type = Enum.random([:hall_up, :hall_down, :cab])
    rnd_floor = Enum.random(0..@max_floor)
    rnd_order = struct(Order, [order_id: rnd_id, order_type: rnd_type, order_floor: rnd_floor])
  end

  def create_rnd_order(
        floor,
        type)
  do
    rnd_id = Time.utc_now()
    rnd_order = struct(Order, [order_id: rnd_id, order_type: type, order_floor: floor])
  end

  @doc """
  Function that returns a list of the cab orders in a list of orders. Returns empty list if none are present
  """
  def extract_cab_orders(order_list)
  when is_list(order_list)
  do
    if is_order_list(order_list) do
      cab_orders = Enum.filter(order_list, fn x -> x.order_type == :cab end)
    end
  end

  @doc """
  Function to check whether list contains only orders or not
  """
  def is_order_list(list)
  when is_list(list)
  do
    Enum.all?(list, fn
      %Order{} -> :true
      _ -> :false
    end)
  end

  def merge_order_lists(
        list1,
        list2)
  when is_list(list1) and is_list(list2)
  do
    list1++list2 |>
      Enum.uniq()
  end


  def get_orders_with_value(
        %Order{} = order,
        field,
        value)
  do
    order_value = Map.get(order, field)
    case order_value == value do
      :true->
        order
      :false->
        []
    end
  end

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
        %Order{} = order,
        field,
        value)
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
