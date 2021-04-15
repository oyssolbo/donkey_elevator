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
      {:master, _from_node, _message_id, {:set_hall_lights, order_list}} ->
        GenServer.cast(@node_name, {:set_hall_lights, order_list})

      {:elevator, _from_node, _message_id, {event_name, data}} ->
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


##### Light-handler #####

  @doc """
  Handler that recieves a list of orders from master or elevator, and
  sets the corresponding lights high
  """
  def handle_cast(
        {:set_hall_lights, external_order_list},
        data)
  do
    set_external_lights(external_order_list)
    {:noreply, data}
  end

  def handle_cast(
        {:set_cab_lights, internal_order_list},
        data)
  do
    set_internal_lights(internal_order_list)
    {:noreply, data}
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
  Function to iterate through a list of orders, and set the corresponding
  light on

  set_internal_lights() - invokes clear_internal_lights() and sets all corresponding internal lights :on
  set_external_ligths() - invokes clear_external_lights() and sets all corresponding external lights :on
  """
  defp set_internal_lights(order_list)
  when order_list |> is_list()
  do
    clear_internal_lights()
    Enum.filter(order_list, fn order -> order.order_type == :cab end) |>
      Enum.each(fn order ->
        Driver.set_order_button_light(:cab, order.order_floor, :on)
      end)
  end

  defp set_external_lights(order_list)
  when order_list |> is_list()
  do
    clear_external_lights()
    Enum.filter(order_list, fn order -> order.order_type in [:hall_up, :hall_down] end) |>
      Enum.each(fn order ->
        Driver.set_order_button_light(order.order_type, order.order_floor, :on)
      end)
  end


  @doc """
  Functions to clear all lights recursively

  clear_internal_lights() - clears all :cab-lights
  clear_external_lights() - clears all :hall_up and :hall_down
  """
  defp clear_internal_lights(floor \\ @min_floor)
  when floor <= @max_floor
  do
    Driver.set_order_button_light(:cab, floor, :off)

    clear_internal_lights(floor + 1)
  end

  defp clear_internal_lights(floor)
  when floor > @max_floor
  do
    :ok
  end

  defp clear_external_lights(floor \\ @min_floor)
  when floor <= @max_floor
  do
    Driver.set_order_button_light(:hall_down, floor, :off)
    Driver.set_order_button_light(:hall_up, floor, :off)

    clear_external_lights(floor + 1)
  end

  defp clear_external_lights(floor)
  when floor > @max_floor
  do
    :ok
  end
end
