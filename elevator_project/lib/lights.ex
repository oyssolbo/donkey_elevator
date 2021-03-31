defmodule Lights do
  @moduledoc """
  Module for setting lights. The module receives a list of active orders
  and sets the corresponding lights high. No storage of which lights are
  active

  Dependencies
    - Driver
  """

  @min_floor  Application.fetch_env!(:elevator_project, :project_min_floor)
  @max_floor  Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1


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
  the lights corresponding to the orders

  orders  List of current active orders
  """
  def set_order_lights(orders)
  do
    clear_all_lights()
    set_all_order_lights(orders)
  end



  @doc """
  Function to clear all lights recursively

  Clears all hall_down, hall_up, cab at each floor
  """
  defp clear_all_lights(floor \\ @min_floor)
  when floor <= @max_floor
  do
    Driver.set_order_button_light(:hall_down, floor, :off)
    Driver.set_order_button_light(:hall_up, floor, :off)
    Driver.set_order_button_light(:cab, floor, :off)

    clear_all_lights(floor + 1)
    :ok
  end

  defp clear_all_lights(_floor)
  do
    :ok
  end


  @doc """
  Function to iterate through a list of orders, and set the corresponding
  light on
  """
  defp set_all_order_lights([%Order{order_type: type, order_floor: floor} = _order | rest_orders])
  do
    if type == :down do
      Driver.set_order_button_light(:hall_down, floor, :on)
    end
    if type == :up do
      Driver.set_order_button_light(:hall_up, floor, :on)
    end
    if type == :cab do
      Driver.set_order_button_light(:cab, floor, :on)
    end
    set_all_order_lights(rest_orders)
  end

  defp set_all_order_lights([])
  do
    :ok
  end
end
