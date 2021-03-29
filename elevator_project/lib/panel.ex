
"""
Order-struct
Example
    l1 = [ID-1, ID-2]
    l2 = [:up, :down]
    l3 = [1, 4]

    orders = Order.zip(l1, l2, l3)

Syntax
    @Order{order_ID, order_type, order_floor}
"""

defmodule Panel do
    require Driver
    require UDP
    require Order

    @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}
    @state_map  %{:on => 1, :off => 0}
    @direction_map %{:up => 1, :down => 255, :stop => 0}

    #numFloors = 4 # Get this from config somehow
    @num_floors Application.fetch_env!(:elevator_project, :num_floors)
    floor_table = Enum.to_list(0..@num_floors-1) # Creates an array of the floors; makes it easier to iterate through
    my_socket = nil
    #myPort = nil

    def init(mid1, mid2, eid, port \\ [], floor_table \\ Enum.to_list(0..@num_floors-1)) do
        my_socket = UDP.open_connection(port)

        checker_ID = spawn(fn -> order_checker([], floor_table) end)
        sender_ID = spawn(fn -> order_sender(my_socket, mid1, mid2, eid, checker_ID, floor_table, 0, []) end)
        {sender_ID, checker_ID}
    end


    defp order_checker(old_orders, floor_table \\ Enum.to_list(0..@num_floors-1)) when is_list(old_orders) do
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

    defp order_sender(my_socket, mid1, mid2, eid, checker_addr, floor_table, send_ID, outgoing_orders) when is_list(outgoing_orders) do

        # If the order matrix isnt empty ...
        if outgoing_orders != [] do

            # ... send the respective  orders to master and elevator
            UDP.send_data(my_socket, mid1, outgoing_orders)
            UDP.send_data(my_socket, mid2, outgoing_orders)
            UDP.send_data(my_socket, eid, outgoing_orders)

            # ... and wait for an ack
            receive do
                {:ack, from, sentID} ->
                    # When ack is recieved, send request to checker for latest order matrix
                    send(checker_addr, {:gibOrdersPls, self()})
                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated send_ID
                        {:order_checker, updated_orders} ->
                            order_sender(my_socket, mid1, mid2, eid, checker_addr, floor_table, send_ID+1, updated_orders)
                            after
                                2000 -> # Send some kind of error, "no response from order_checker"
                    end
                # If no ack is received after 1.5 sec: Recurse and repeat
                after
                    1500 -> order_sender(my_socket, mid1, mid2, eid, checker_addr, floor_table, send_ID, outgoing_orders)
            end

        else 
            # If order matrix is empty, send request to checker for latest orders. Recurse with those (but same sender ID)
            send(checker_addr, {:gibOrdersPls, self()})
                    receive do
                        {:order_checker, updated_orders} ->
                            order_sender(my_socket, mid1, mid2, eid, checker_addr, floor_table, send_ID, updated_orders)
                    end
        end
     
    end

    defp hardware_order_checker(floor, type) do
        if Driver.get_order_button_state(floor, type) == :on do
            order = struct(Order, [order_id: Kernel.make_ref(), order_type: type, order_floor: floor])
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

end