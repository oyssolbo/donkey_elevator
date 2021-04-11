defmodule Lights do
  @moduledoc """
  Module for setting lights. The module receives a list of active orders
  and sets the corresponding lights high.

  The module must send messages to elevator and master. Lights are set based on updates
  from these modules, and are cleared when either the elevator or the master messages a
  list of orders that are served

  Dependencies
    - Driver
    - Order
    - Network
  """

  use GenServer

  require Logger
  require Driver
  require Order
  require Network

  @min_floor    Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor    Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1

  @node_name    :lights


##### Initialization #####
  @doc """
  Initializes lights to store and set any old orders
  """
  def init(old_orders \\ [])
  do
    init_receive()

    set_lights(old_orders)
    {:ok, old_orders}
  end


  @doc """
  Initializes the link with GenServer
  """
  def start_link(args \\ [])
  do
    opts = [name: @node_name]
    GenServer.start_link(__MODULE__, args, opts])
  end


##### External network #####
  defp receive_thread(%{master_msg_id: master_msg_id, elevator_msg_id: elevator_msg_id} = msg_id)
  do
    updated_msg_id_map =
      receive do
        {:master, from_node, message_id, {event_name, data}} ->
          # Ugly logic preventing old messages to overwrite newer messages
          # But this is invalid when the master/elevator is restarted...

          if message_id > master_msg_id do
            GenServer.cast(@node_name, {event_name, data})
            message_id
          end
          Network.send_data_all_nodes(:master, :lights, {message_id, :ack})

        {:elevator, _from_node, message_id, {event_name, data}} ->

          GenServer.cast(@node_name, {event_name, data})
          Network.send_data_inside_node(:elevator, :lights, {message_id, :ack})
      end

    receive_thread()
  end


  defp init_receive()
  do
    spawn_link(fn -> receive_thread() end) |>
      Process.register(:lights_receive)
  end


##### Implementing global (external) lights #####
  def handle_cast(
        {:set_lights, set_order_list},
        order_list)
  do
    updated_order_list = Order.add_overs(set_order_list, order_list)
    set_order_lights(updated_order_list)

    {:ok, updated_order_list}
  end


  def handle_cast(
      {:clear_lights, clear_order_list},
      order_list}
  do
    clear_all_lights()

    updated_order_list = Order.remove_overs(clear_order_list, order_list)
    set_order_lights(updated_order_list)

    {:ok, updated_order_list}
  end


##### Old functions #####

  @doc """
  Set floorlight at the given 'floor'
  """
  def set_floorlight(floor)
  do
    Driver.set_floor_indicator(floor)
  end


  @doc """
  Set the doorlight to the state 'state'
  """
  def set_door_light(state)
  do
    Driver.set_door_open_light(state)
  end


  @doc """
  Set order-lights. The function first turns off all other lights, before setting
  the lights corresponding to a list of orders 'order_list'
  """
  def set_order_lights(order_list)
  do
    clear_all_lights()
    set_all_order_lights(order_list)
  end



  @doc """
  Function to clear all lights recursively

  Clears all hall_down, hall_up, cab at each floor
  """
  def clear_all_lights(floor \\ @min_floor)
  when floor <= @max_floor
  do
    Driver.set_order_button_light(:hall_down, floor, :off)
    Driver.set_order_button_light(:hall_up, floor, :off)
    Driver.set_order_button_light(:cab, floor, :off)

    clear_all_lights(floor + 1)
    :ok
  end

  def clear_all_lights(_floor)
  do
    :ok
  end


  @doc """
  Function to iterate through a list of orders, and set the corresponding
  light on
  """
  defp set_all_order_lights([first_order | rest_orders] = order_list)
  do
    if Order.is_order_list(order_list) do
      case Map.get(first_order, :order_type) do
        :hall_up ->
          Driver.set_order_button_light(:hall_up, Map.get(first_order, :order_floor), :on)
        :hall_down ->
          Driver.set_order_button_light(:hall_down, Map.get(first_order, :order_floor), :on)
        :cab ->
          Driver.set_order_button_light(:cab, Map.get(first_order, :order_floor), :on)
      end
    end
    set_all_order_lights(rest_orders)
  end

  defp set_all_order_lights([])
  do
    :ok
  end


end
