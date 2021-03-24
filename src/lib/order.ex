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
end