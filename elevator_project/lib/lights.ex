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
  Initializes receiver-function, and stores an empty list as
  active lights
  """
  def init(_init_arg \\ [])
  do
    init_receive()
    {:ok, []}
  end


  @doc """
  Starts the link to GenServer
  """
  def start_link(args \\ [])
  do
    opts = [name: @node_name]
    GenServer.start_link(__MODULE__, args, opts)
  end


##### External network #####

  @doc """
  Function that receives orders from master and elevator on which
  orders to be set/cleared. The entire system communicates with the
  lights through this function
  """
  defp receive_thread()
  do
    receive do
      {:master, _from_node, _message_id, {event_name, data}} ->
        Logger.info("Received light update from master")
        GenServer.cast(@node_name, {event_name, data})

      {:elevator, _from_node, _message_id, {event_name, data}} ->
        Logger.info("Received light update from elevator")
        GenServer.cast(@node_name, {event_name, data})
    end

    receive_thread()
  end

  @doc """
  Initialization for the receive-thread
  """
  defp init_receive()
  do
    spawn_link(fn -> receive_thread() end) |>
      Process.register(:lights_receive)
  end


##### Implementing lights #####

  @doc """
  Handler that recieves a list of orders from either the master or elevator, and
  sets the corresponding lights high
  """
  def handle_cast(
        {:set_lights, set_order_list},
        order_list)
  do
    updated_order_list = Order.add_orders(set_order_list, order_list)
    set_order_lights(updated_order_list)

    {:noreply, updated_order_list}
  end


  @doc """
  Handler that recieves a list of orders from master or elevator that is served.
  It removes the orders, and sets the remaining corresponding lights high
  """
  def handle_cast(
        {:clear_lights, clear_order_list},
        order_list)
  do
    clear_all_lights()

    updated_order_list = Order.remove_orders(clear_order_list, order_list)
    set_order_lights(updated_order_list)

    {:noreply, updated_order_list}
  end

  @doc """
  Handler that sets the floor-light on a given floor 'floor' high
  """
  def handle_cast(
        {:set_floor_light, floor},
        order_list)
  when floor >= @min_floor and floor <= @max_floor
  do
    Driver.set_floor_indicator(floor)

    {:noreply, order_list}
  end


  @doc """
  Handler that sets the door as 'state'
  """
  def handle_cast(
        {:set_door_light, state},
        order_list)
  when state in [:on, :off]
  do
    Driver.set_door_open_light(state)

    {:noreply, order_list}
  end


##### Workhorse-functions #####

  @doc """
  Set order-lights. The function first turns off all other lights, before setting
  the lights corresponding to a list of orders 'order_list'
  """
  defp set_order_lights(order_list)
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
  end

  def clear_all_lights(floor)
  when floor > @max_floor
  do
    :ok
  end


  @doc """
  Function to iterate through a list of orders, and set the corresponding
  light on
  """
  defp set_all_order_lights(order_list)
  do
    if Order.is_order_list(order_list) do
      Enum.each(order_list, fn order ->
        case Map.get(order, :order_type) do
          :hall_up ->
            Driver.set_order_button_light(:hall_up, Map.get(order, :order_floor), :on)
          :hall_down ->
            Driver.set_order_button_light(:hall_down, Map.get(order, :order_floor), :on)
          :cab ->
            Driver.set_order_button_light(:cab, Map.get(order, :order_floor), :on)
        end
      end)
    end
  end
end
