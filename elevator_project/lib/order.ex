defmodule Order do
  @moduledoc """
  Module that implements 'Orders' and includes a function to zip multiple orders into a
  list. This makes it easier to send
  """

  defstruct [order_id: :nil, order_type: :nil, order_floor: :nil]

  @doc """
  Zips multiple orders into a list

  order_ids     List of each order's ID. For example time the order is given
  order_types   List of each order's type; :up, :down, :cab
  order_floors  List of each order's floor; 0, 1, 2, 3, ...

  Example
    l1 = [make_ref(), make_ref()]
    l2 = [:up, :down]
    l3 = [1, 4]

    orders = Order.zip(l1, l2, l3)
  """
  def zip(order_ids, order_types, order_floors) do
    zip(order_ids, order_types, order_floors, [])
  end

  defp zip([order_id | rest_id], [order_type | rest_types], [order_floor | rest_floors], orders) do
    zip(rest_id, rest_types, rest_floors,
    [
      %Order{order_id: order_id, order_type: order_type, order_floor: order_floor} | orders
    ])
  end

  defp zip(_, _, _, orders) do
    :lists.reverse(orders)
  end


  @doc """
  Function to check if an order is valid

  For the order to be valid, we require that:
    - order_floor is between min and max
    - order_type is either :cab, :up, :down
  """
  def check_valid_orders([order | rest_orders]) do
    case check_valid_order(order) do
      :ok->
        check_valid_orders(rest_orders)
      {:error, id}->
        IO.puts("Invalid order found! Order's ID given as")
        IO.inspect(id)
        :error
    end
  end

  def check_valid_orders([]) do
    :ok
  end

  defp check_valid_order(%Order{order_id: id, order_type: type, order_floor: floor}) do
    min_floor = Application.fetch_env!(:elevator_project, :min_floor)
    num_floors = Application.fetch_env!(:elevator_project, :num_floors)

    if floor < min_floor or floor > min_floor + num_floors - 1 do
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
end
