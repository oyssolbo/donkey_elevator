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
        [] = _new_orders,
        order_list)
  when is_list(order_list)
  do
    order_list |>
      Enum.uniq()
  end

  def add_orders(
        new_orders,
        order_list)
  when is_list(order_list)
  and is_list(new_orders)
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
    # Enum.map(orders, fn order -> remove_orders(order, order_list) end)
    new_order_list = remove_orders(first_order, order_list)
    remove_orders(rest_orders, new_order_list)
  end


## Extract orders(s) ##

  @doc """
  Function that extracts all orders that have the type 'type'
  Example; extracts all orders with type ':cab' from a list of orders
  """
  def extract_orders(
        type,
        order_list)
  when order_list |> is_list()
  and type in [:hall_up, :hall_down, :cab]
  do
    Enum.filter(order_list, fn x -> x.order_type == type end)
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
    Enum.filter(order_list, fn x -> x.delegated_elevator == elevator_id end)
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
  when is_list(order_list)
  and is_integer(floor)
  and dir in [:up, :down]
  do
    hall_dir = convertion_dir_hall_dir(dir)
    Enum.filter(order_list, fn x ->
      x.order_floor == floor and
      x.order_type in [hall_dir, :cab]
    end)
  end


  @doc """
  Function that extracts a list of orders with a given type at a given
  floor.
  """
  def extract_orders(
        floor,
        type,
        order_list)
  when is_list(order_list)
  and is_integer(floor)
  and type in [:hall_up, :hall_down, :cab]
  do
    Enum.filter(order_list, fn x ->
      x.order_floor == floor and
      x.order_type == type
    end)
  end


## Check order(s) ##
  @doc """
  Function to check if an order is valid. Invalid orders should not occur!
  If this function causes a crash, it is likely that an order is set to
  default (:nil)
  For the order to be valid, we require that:
    - order_floor is between min and max
    - order_type is either :cab, :hall_up, :hall_down
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
      type not in [:cab, :hall_up, :hall_down]->
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
  Function that checks is there are similar orders already in a list of orders.
  The function checks both the type and the floor, and returns a list with any
  duplicates removed
  """
  def check_and_remove_duplicates(
        check_orders,
        order_list)
  when order_list |> is_list()
  and check_orders |> is_list
  do
    Enum.filter(check_orders, fn order ->
      extract_orders(order.order_floor, order.order_type, order_list) == []
    end) ++
      order_list
  end



  @doc """
  Function to check whether a list contains only orders or not
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
    Enum.map(orders, fn order -> Map.put(order, field, value) end)
  end

## Conversion between dir and hall_dir ##

  @doc """
  Function that convertes between elevator's dir [:up, :down] and
  [:hall_up, :hall_down]. If the given parameter is something else, and error
  is returned
  """
  defp convertion_dir_hall_dir(convert_dir)
  do
    case convert_dir do
      :down -> :hall_down
      :hall_down -> :down
      :up -> :hall_up
      :hall_up -> :up
      _ -> :error
    end
  end
end
