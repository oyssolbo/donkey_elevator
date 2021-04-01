defmodule Order do
  @moduledoc """
  Module that implements 'Orders' and includes a function to zip multiple orders into a
  list. This makes it easier to send
  """

  require ListOperations

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
          orders,
          dir,
          floor)
  do
    orders_at_floor = get_orders_with_value(orders, :order_floor, floor)

    order_in_dir = get_orders_with_value(orders_at_floor, :order_type, dir)
    order_in_cab = get_orders_with_value(orders_at_floor, :order_type, :cab)

    #temp_orders = remove_order_list_from_list(order_in_dir, orders)
    #remove_order_list_from_list(order_in_cab, temp_orders)

    temp_orders = ListOperations.remove_list_from_list(order_in_dir, orders)
    ListOperations.remove_list_from_list(order_in_cab, temp_orders)

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

  def remove_floor_orders(
        [],
        _dir,
        _floor)
  do
    []
  end


  @doc """
  Function to remove a list of orders from another list of orders

  It is assumed that there is only one copy of each order in the list
  """
  def remove_orders(
        orders,
        order_list)
  when orders |> is_list()
  do
    # new_list = List.delete(list, order)
    # remove_order_list_from_list(rest_orders, new_list)

    ListOperations.remove_list_from_list(orders, order_list)

  end

  def remove_orders(
        order,
        order_list)
  when order |> is_struct()
  do
    ListOperations.remove_element_from_list(order, order_list)
  end


  @doc """
  Function to add a list of orders to another list of orders
  """
  def add_order(
        orders,
        order_list)
  when orders |> is_list()
  do
    ListOperations.add_list_to_list(orders, order_list)
  end

  def add_order(
        order,
        order_list)
  when order |> is_struct()
  do
    ListOperations.add_single_element_to_list(order, order_list)
  end


  @doc """
  Function to add a single order to a list 'list'
  """
  # def add_orders_to_list(
  #       new_order,
  #       list)
  # do
  #   cond do
  #     list == []->
  #       [new_order]
  #     new_order in list->
  #       list
  #     new_order not in list->
  #       [list | new_order]
  #   end
  # end


## Valid orders ##
  @doc """
  Function to check if an order is valid

  For the order to be valid, we require that:
    - order_floor is between min and max
    - order_type is either :cab, :up, :down
  """
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


  def check_valid_order(order)
  when order |> is_struct()
  do
    floor = Map.get(order, :order_floor)
    type = Map.get(order, :order_type)
    cond do
      floor < @min_floor->
        IO.puts("Invalid floor")
        :error
      floor > @max_floor->
        IO.puts("Invalid floor")
        :error
      type not in [:cab, :up, :down]->
        IO.puts("Invalid type")
        :error
      :true->
        :ok
    end
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
        orders,
        #[order | rest_orders],
        field,
        value)
  do
    ListOperations.find_element_with_value(orders, field, value)

    # order_value = Map.get(order, field, value)
    # if order_value == value do
    #   [order | get_orders_with_value(rest_orders, field, value)]
    # else
    #   get_orders_with_value(rest_orders, field, value)
    # end
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
    #set_order_field(orders, :delegated_elevator, elevator_id)
    ListOperations.set_element_field(orders, :delegated_elevator, elevator_id)
  end


  @doc """
  Functions that gets all orders which are assigned to an elevator with the id
  'elevator_id'
  """
  def get_delegated_elevator(
        orders,
        elevator_id)
  do
    ListOperations.find_element_with_value(orders, :delegated_elevator, elevator_id)
  end


  @doc """
  Sets the field 'field' in an order to an assigned 'value'

  Recurses over the entire list, such that all orders in the list get the
  desired 'value'

  Returns the new list
  """
    def gib_rnd_order() do
        rnd_id = Time.utc_now()
        rnd_type = Enum.random([:hall_up, :hall_down, :cab])
        rnd_floor = Enum.random(0..@max_floor)
        rnd_order = struct(Order, [order_id: rnd_id, order_type: rnd_type, order_floor: rnd_floor])
    end

    def gib_rnd_order(floor, type) do
        rnd_id = Time.utc_now()
        rnd_order = struct(Order, [order_id: rnd_id, order_type: type, order_floor: floor])
    end

    @doc """
    Function that returns a list of the cab orders in a list of orders. Returns empty list if none are present
    """
    def extract_cab_orders(order_list) when is_list(order_list) do
        if is_order_list(order_list) do
            cab_orders = Enum.filter(order_list, fn x -> x.order_type == :cab end)
        end
    end

    @doc """
    Function to check whether list contains only orders or not
    """
    def is_order_list(list) when is_list(list) do
        Enum.all?(list, fn
            %Order{} -> true
            _ -> false
        end)
    end

    def merge_lists(list1, list2) when is_list(list1) and is_list(list2) do
      lst = list1++list2
      lst = Enum.uniq(lst)
    end

  # defp set_order_field(
  #       [order | rest_orders],
  #       field,
  #       value)
  # do
  #   [
  #     Map.put(order, field, value) |
  #     set_order_field(rest_orders, field, value)
  #   ]
  # end

  # defp set_order_field(
  #       [],
  #       field,
  #       value)
  # do
  #   []
  # end

end
