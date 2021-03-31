defmodule BETest do
  # use ExUnit.Case
  # doctest ElevatorProject

  # test "greets the world" do
  #   assert ElevatorProject.hello() == :world
  # end

  @moduledoc """
  Test for checking if the states for the barebones-elevator transitions correctly

  Required / desired tests:
    - Init works correctly (if it does not reach a desired floor, it forces a restart)
    - Transitions from init to emergency when it takes too long
  """

  def test_elevator_init()
  do
    BareElevator.start_link()
    Process.sleep(500)
  end

  def test_elevator_init_to_idle()
  do
    test_elevator_init()
    BareElevator.check_at_floor(1)
    Process.sleep(500)
  end

  def test_elevator_idle_to_moving()
  do
    test_elevator_init_to_idle()
    order = %Order{order_id: make_ref(), order_floor: 2, order_type: :cab}
  end


end
