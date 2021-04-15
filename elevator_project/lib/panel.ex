
defmodule Panel do
    @moduledoc """
    Module for detecting button inputs on the elevator panel, and passing the information on
    to relevant modules

    Dependencies:
    - Driver
    - Network
    - Order
    """

    use GenServer

    require Driver
    require Network
    require Order
    require Logger

    @min_floor          Application.fetch_env!(:elevator_project, :project_min_floor)
    @max_floor          Application.fetch_env!(:elevator_project, :project_num_floors) + @min_floor - 1

    @ack_timeout_time   Application.fetch_env!(:elevator_project, :network_ack_timeout_time_ms)
    @panel_sleep_time   Application.fetch_env!(:elevator_project, :panel_sleep_time_ms)

    @node_name          :panel

    @doc """
    Initializes the panel module by spawning the function 'check_and_send_orders'. If this
    process dies, the Supervisor restarts
    """
    def init(floor_table)
    do
        pid = spawn_link(fn -> check_and_send_orders(floor_table, []) end)
        Process.register(pid, :panel)
        {:ok, pid}
    end

    @doc """
    Starts a link to the GenServer-process
    """
    def start_link([])
    do
        args = Enum.to_list(@min_floor..@max_floor)
        opts = [@node_name]
        GenServer.start_link(__MODULE__, args, opts)
    end

    @doc """
    Kills the process in case of a major error
    """
    def terminate(_reason, _state)
    do
      Logger.info("Panel given order to terminate. Terminating")
      Process.exit(self(), :normal)
    end



    @doc """
    Checks the hardware for any new orders, and tries to send the message to elevator
    and master. If an ack is not received within @ack_timeout_time, the orders are
    kept for the next iteration. Otherwise, it is assumed that all orders have
    reached the target, such that these orders are cleared
    """
    defp check_and_send_orders(
            floor_table,
            previous_orders \\ [])
    when previous_orders |> is_list()
    do
        Process.sleep(@panel_sleep_time)
        current_orders = check_for_new_orders(floor_table, previous_orders)
        if not hot_buttons?(floor_table) do
            orders_to_elevator = Order.extract_orders(:cab, current_orders)
            orders_to_masters =
                Order.extract_orders(:hall_up, current_orders) ++
                Order.extract_orders(:hall_down, current_orders)

            master_msg_id = Network.send_data_all_nodes(:panel, :master_receive, orders_to_masters)
            if orders_to_elevator != [] do
                Network.send_data_inside_node(:panel, :elevator_receive, {:delegated_order, orders_to_elevator})
            end

            updated_orders =
            receive do
                {:master, _from_node, _message_id, {master_msg_id, :ack}}->
                    []
            after @ack_timeout_time->
                orders_to_masters
            end
            check_and_send_orders(floor_table, updated_orders)
        else
            check_and_send_orders(floor_table, current_orders)
        end
    end


    @doc """
    Functions for extracting orders from hardware.
        check_for_new_orders()  - checks for new orders given to hardware
        get_order_list()        - gets a list of orders with given type and floor
        check_hardware()        - checks hardware for an order at a given floor and with a certain type
        check_stored_order?()   - checks if there are any orders (that are not sent) with the current
                                    type and floor
    """
    defp check_for_new_orders(
            floor_table,
            previous_orders)
    when previous_orders |> is_list()
    do
        orders =
            get_order(:hall_up, floor_table, previous_orders) ++
            get_order(:hall_down, floor_table, previous_orders) ++
            get_order(:cab, floor_table, previous_orders)

        Enum.concat(orders, previous_orders) |>
            Enum.uniq()
    end

    defp get_order(
        order_type,
        floor_table,
        previous_orders)
    do
        Enum.map(floor_table, fn floor -> check_hardware(floor, order_type, previous_orders) end) |>
            Enum.reject(fn orders -> orders == [] end)
    end

    defp check_hardware(
            floor,
            type,
            previous_orders)
    do
        try do
            already_stored = check_stored_order?(floor, type, previous_orders)

            if Driver.get_order_button_state(floor, type) == 1 and not already_stored do
                struct(Order, [order_id: Timer.get_utc_time(), order_type: type, order_floor: floor])
            else
                []
            end

        catch
            :exit, _reason ->
                Logger.error("DRIVER NOT DETECTED")
                []
        end
    end

    defp check_stored_order?(
            _floor,
            _type,
            previous_orders)
    when previous_orders == []
    do
        :false
    end

    defp check_stored_order?(
            floor,
            type,
            previous_orders)
    when previous_orders != []
    do
        Enum.any?(previous_orders, fn order -> order.order_floor == floor and order.order_type == type end)
    end

    def hot_buttons?(floor_table) do
        butts = Enum.map(floor_table, fn floor -> Driver.get_order_button_state(floor, :hall_up) end)++Enum.map(floor_table, fn floor -> Driver.get_order_button_state(floor, :hall_down) end)++Enum.map(floor_table, fn floor -> Driver.get_order_button_state(floor, :cab) end)
        Enum.any?(butts, fn num -> num != 0 end)
    end
end
