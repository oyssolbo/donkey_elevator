defmodule Lights do
  @moduledoc """
  Module for setting lights. The module receives a list of active orders
  and sets the corresponding lights high.

  The module must send messages to elevator and master. Lights are set based on updates
  from these modules. All other lights are cleared, and by updating which orders are
  active, the lights are indirectly cleared.

  Based on the functionality of the lights-module, it would not be required
  to save the states of internal and external orders as well as the last known
  elevator-floor. This is done to prevent unecessary use of bandwith for the driver

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

  @enforce_keys [:internal_orders, :external_orders, :floor_light]
  defstruct     [:internal_orders, :external_orders, :floor_light]


##### Initialization #####

  @doc """
  Initializes receiver-function, and stores an empty list as active lights.
  """
  def init(_init_arg \\ [])
  do
    lights_data = %Lights{
      internal_orders:  [],
      external_orders:  [],
      floor_light:      :nil
    }

    clear_external_lights()
    clear_internal_lights()

    init_receive()
    {:ok, lights_data}
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
        {:set_hall_lights, new_external_orders},
        %Lights{external_orders: old_external_orders} = lights_data)
  when new_external_orders |> is_list()
  do
    new_lights_data =
    case Enum.sort(new_external_orders) == Enum.sort(old_external_orders) do
      :true->
        lights_data
      :false->
        set_external_lights(new_external_orders)
        Map.put(lights_data, :external_orders, new_external_orders)
    end
    {:noreply, new_lights_data}
  end

  def handle_cast(
        {:set_cab_lights, new_internal_orders},
        %Lights{internal_orders: old_internal_orders} = lights_data)
  when new_internal_orders |> is_list()
  do
    new_lights_data =
    case Enum.sort(new_internal_orders) == Enum.sort(old_internal_orders) do
      :true->
        lights_data
      :false->
        set_internal_lights(new_internal_orders)
        Map.put(lights_data, :internal_orders, new_internal_orders)
    end
    {:noreply, new_lights_data}
  end


  @doc """
  Handler that sets the floor-light on a given floor 'floor' high
  """
  def handle_cast(
        {:set_floor_light, floor},
        %Lights{floor_light: last_floor} = lights_data)
  when floor >= @min_floor and floor <= @max_floor
  do
    new_lights_data =
    case last_floor == floor do
      :true->
        lights_data
      :false->
        Driver.set_floor_indicator(floor)
        Map.put(lights_data, :floor_light, floor)
    end
    {:noreply, new_lights_data}
  end


  @doc """
  Handler that sets the door as 'state'
  """
  def handle_cast(
        {:set_door_light, state},
        lights_data)
  when state in [:on, :off]
  do
    Driver.set_door_open_light(state)
    {:noreply, lights_data}
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
