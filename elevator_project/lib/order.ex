defmodule Order do
  @moduledoc """
  Module that implements the struct 'Order' with different functions for operating
  on them
  """

  require Logger

  @min_floor Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1


  defstruct [
    order_id:           :nil,
    order_type:         :nil,
    order_floor:        :nil,
    delegated_elevator: :nil
  ]

## Add order(s) ##
  @doc """
  Function to add order(s) to a list of orders
  """
  def add_orders(
        %Order{} = order,
        order_list)
  when is_list(order_list)
  do
    [order]++order_list |>
      Enum.uniq()
  end

  def add_orders(
        new_orders,
        order_list)
  when is_list(order_list) and is_list(new_orders)
  do
    new_orders++order_list |>
      Enum.uniq()
  end


## Remove order(s) ##
  @doc """
  Function that removes a single or a list of orders from another list of orders

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
        [],
        order_list)
  when is_list(order_list)
  do
    order_list
  end

  def remove_orders(
        [first_order | rest_orders] = _orders,
        order_list)
  when is_list(order_list)
  do
    if is_order_list(order_list) do
      # Enum.map(orders, fn order -> remove_orders(order, order_list) end)
      new_order_list = remove_orders(first_order, order_list)
      remove_orders(rest_orders, new_order_list)
    else
      Logger.info("Not an order-list")
      []
    end
  end


## Extract orders(s) ##

  @doc """
  Function that extract a list order corresponding to a list of ids 'order_id_list'. Returns
  an empty list if not found, or if the list did not contain only orders
  """
  def extract_order(
        [first_order_id | rest_order_id] = order_id_list,
        order_list)
  when order_list |> is_list() and order_id_list |> is_list()
  do
    [extract_order(first_order_id, order_list) | extract_order(rest_order_id, order_list)]
  end


  @doc """
  Function that extract a single order with id 'order_id' from a list of orders. Returns
  an empty list if not found, or if the list did not contain only orders
  """
  def extract_order(
        order_id,
        order_list)
  when order_list |> is_list()
  do
    if is_order_list(order_list) do
      Enum.filter(order_list, fn x -> x.order_id == order_id end)
    else
      Logger.info("Not an order-list")
      []
    end
  end


  @doc """
  Function to get all orders at floor 'floor' in a list of orders
  that satisfies the required [:dir, :cab]. If there are no orders
  fulfilling the requirements, the function returns an empty list
  """
  def extract_orders(
        floor,
        dir,
        order_list)
  when is_list(order_list) and is_integer(floor) and dir in [:down, :up]
  do
    Enum.filter(order_list, fn x ->
      x.order_floor == floor and
      x.order_type in [dir, :cab]
    end)
  end


  @doc """
  Function that extracts all orders that have the type 'type'

  Example; extracts all orders with type ':cab' from a list of orders
  """
  def extract_orders(
        type,
        order_list)
  when order_list |> is_list() and type in [:up, :down, :cab]
  do
    if is_order_list(order_list) do
      Enum.filter(order_list, fn x -> x.order_type == type end)
    else
      Logger.info("Not an order-list")
      []
    end
  end


  @doc """
  Function that extracts a list of orders that is delegated to an elevator 'elevator_id'
  from another list of orders. Returns an empty list if no orders found
  """
  def extract_orders(
        elevator_id,
        order_list)
  when order_list |> is_list()
  do
    if is_order_list(order_list) do
      Enum.filter(order_list, fn x -> x.delegated_elevator == elevator_id end)
    else
      Logger.info("Not an order-list")
      []
    end
  end

## Check order(s) ##
  @doc """
  Function to check if an order is valid. Invalid orders should not occur!

  If this function causes a crash, it is likely that an order is set to
  default (:nil)

  For the order to be valid, we require that:
    - order_floor is between min and max
    - order_type is either :cab, :up, :down
  """
  def check_valid_order(%Order{order_floor: floor, order_type: type} = _order)
  do
    cond do
      floor < @min_floor->
        Logger.info("Invalid floor. Less than min-floor")
        :false
      floor > @max_floor->
        Logger.info("Invalid floor. Greater than max-floor")
        :false
      type not in [:cab, :up, :down]->
        Logger.info("Invalid type")
        :false
      :true->
        :true
    end
  end


  def check_valid_order(orders)
  when is_list(orders)
  do
    Enum.all?(orders, fn order -> check_valid_order(order) end)
  end


  @doc """
  Function to check if there are orders on floor 'floor' with the
  direction 'dir' or ':cab'
  """
  def check_orders_at_floor(
        orders,
        floor,
        dir)
  do
    case extract_orders(floor, dir, orders) do
      [] ->
        {:false, []}
      orders ->
        {:true, orders}
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

## Modify order ##
  @doc """
  Function that modifies a field in a single order, or a list of orders. The
  field 'field' is set to value 'value'
  """
  def modify_order_field(
        %Order{} = order,
        field,
        value)
  do
    Map.put(order, field, value)
  end

  def modify_order_field(
        orders,
        field,
        value)
  when orders |> is_list()
  do
    if is_order_list(orders) do
      Enum.map(orders, fn order -> Map.put(order, field, value) end)
    else
      Logger.info("Not an order-list")
      orders
    end
  end

## Create random order ##
  @doc """
  Creates random order
  """
  def create_rnd_order()
  do
    rnd_id = Time.utc_now()
    rnd_type = Enum.random([:hall_up, :hall_down, :cab])
    rnd_floor = Enum.random(0..@max_floor)
    struct(Order, [order_id: rnd_id, order_type: rnd_type, order_floor: rnd_floor])
  end

  def create_rnd_order(
        floor,
        type)
  do
    rnd_id = Time.utc_now()
    struct(Order, [order_id: rnd_id, order_type: type, order_floor: floor])
  end
end
