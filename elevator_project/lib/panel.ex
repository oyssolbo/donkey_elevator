"""
Syntax
    @Order{order_ID, order_type, order_floor}
"""


defmodule Panel do
    require Driver
    require Network
    require Order

    use GenServer

    #@button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}
    #@state_map  %{:on => 1, :off => 0}
    #@direction_map %{:up => 1, :down => 255, :stop => 0}

    @num_floors Application.fetch_env!(:elevator_project, :project_num_floors)
    # floor_table: Array of the floors; makes it easier to iterate through

    # TODO: Replace mid1, mid2, eid with send_local_node func. For master send; send_data_to_all_nodes.
    def init(floor_table \\ Enum.to_list(0..@num_floors-1)) do

        checker_ID = spawn(fn -> order_checker([], floor_table) end)
        sender_ID = spawn(fn -> order_sender(checker_ID, floor_table, 0, []) end)

        # Register the processes in the local node
        Process.register(checker_ID, :order_checker)
        Process.register(sender_ID, :panel)

        {checker_ID, sender_ID}
        {:ok, "hello"}
    end

    defp order_checker(old_orders, floor_table) when is_list(old_orders) do
        orders = []
        # Update order list by reading all HW order buttons
        if old_orders == [] do
            orders = check_4_orders(floor_table)
        else
            orders = old_orders++check_4_orders(floor_table)
        end

        # Check for request from sender. If there is, send order list and recurse with reset list
        receive do
            {:gibOrdersPls, sender_addr} ->
                send(sender_addr, {:order_checker, orders})
                order_checker([], floor_table)
            after
                0 -> :ok
        end

        # If no send request, requrse with current list (output buffer)
        order_checker(orders, floor_table)
    end

    defp order_sender(checker_addr, floor_table, send_ID, outgoing_orders) when is_list(outgoing_orders) do

        # If the order matrix isnt empty ...
        if outgoing_orders != [] do
            Network.send_data_all_nodes(:panel, :master, outgoing_orders)
            Network.send_data_inside_node(:panel, :master, Order.extract_orders(:cab, outgoing_orders))
            #send({:elevator, node}, {:cab_orders, :panel, self(), extract_cab_orders(orders)})

            # ... and wait for an ack
            receive do
                {:ack, from, sentID} ->
                    # When ack is recieved for current send_ID, send request to checker for latest order matrix
                    if sentID == send_ID do
                        send(checker_addr, {:gibOrdersPls, self()})
                    end
                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated send_ID
                        {:order_checker, updated_orders} ->
                            order_sender(checker_addr, floor_table, send_ID+1, updated_orders)
                            after
                                2000 -> # Send some kind of error, "no response from order_checker"
                    end
                # If no ack is received after 1.5 sec: Recurse and repeat
                after
                    1500 -> order_sender(checker_addr, floor_table, send_ID, outgoing_orders)
            end

        else
            # If order matrix is empty, send request to checker for latest orders. Recurse with those (but same sender ID)
            send(checker_addr, {:gibOrdersPls, self()})
            receive do
                {:order_checker, updated_orders} ->
                    order_sender(checker_addr, floor_table, send_ID, updated_orders)
            end
        end

    end

    defp hardware_order_checker(floor, type) do
        if Driver.get_order_button_state(floor, type) == :on do
            # TODO: Replace Time.utc_now() with wrapper func from Timer module
            order = struct(Order, [order_id: Time.utc_now(), order_type: type, order_floor: floor])
        else
            order = []
        end
    end

    defp check_order(orderType, table \\ Enum.to_list(0..@num_floors-1)) do
        sendor_states = Enum.map(table, fn x -> hardware_order_checker(x, orderType) end)
        orders = Enum.filter(sendor_states, fn x -> x == [] end)
    end

    defp check_4_orders(table \\ Enum.to_list(0..@num_floors-1)) do
        orders = check_order(:hall_up, table)++check_order(:hall_down, table)++check_order(:cab, table)
    end

    def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
    end

    def start_link(init_arg \\ [])
    do
    server_opts = [name: :panel_module]
    GenServer.start_link(__MODULE__, init_arg, server_opts)
    end

end
