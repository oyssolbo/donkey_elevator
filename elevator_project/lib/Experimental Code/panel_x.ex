"""
Syntax
    @Order{order_ID, order_type, order_floor}
"""

defmodule Panel_X do
    @moduledoc """
    Module for detecting button inputs on the elevator panel, and passing the information on to relevant modules.

    Dependancies:
    - Driver
    - Network
    - UDP
    - Order
    """
    require Driver
    require UDP
    require Network
    require Order

    @num_floors Application.fetch_env!(:elevator_project, :project_num_floors)
    # floor_table: Array of the floors; makes it easier to iterate through

    # INITIALIZATION FUNTIONS

    @doc """
    Initializes the panel module by spawning the 'order checker' and 'order sender' processes,
    and registering them at the local node as :order_checker and :panel respectively.

    Returns a tuple with their PIDs.

    init(sender_ID, floor_table) will only initialize the checker process and is used by the sender
    in the case that the checker stops responding.
    """
    def init(floor_table \\ Enum.to_list(0..@num_floors-1)) do

        checker_ID = init_checker(floor_table)
        sender_ID = init_sender(floor_table)
        init_dummy_master()

        {checker_ID, sender_ID}
    end

    def init_checker(floor_table) do
        must_die = Process.whereis(:order_checker)
        if must_die != nil do
           Process.exit(must_die, :kill)
        end
        Process.sleep(150)
        checker_ID = spawn(fn -> order_checker([], floor_table) end)
        Process.register(checker_ID, :order_checker)

        init_sender_guardian(floor_table)

        checker_ID
    end

    defp init_checker_guardian(floor_table) do
        must_die = Process.whereis(:checker_guardian)
        if must_die != nil do
            Process.exit(must_die, :kill)
        end
        Process.sleep(150)
        chk_guard_ID = spawn(fn -> checker_guardian(floor_table) end)
        Process.register(chk_guard_ID, :checker_guardian)

        chk_guard_ID  
    end

    def init_sender(floor_table) do
        must_die = Process.whereis(:panel)
        if must_die != nil do
            Process.exit(must_die, :kill)
        end
        Process.sleep(150)
        sender_ID = spawn(fn -> order_sender(floor_table, 0, []) end)
        Process.register(sender_ID, :panel)

        init_checker_guardian(floor_table)

        sender_ID        
    end

    defp init_sender_guardian(floor_table) do
        must_die = Process.whereis(:sender_guardian)
        if must_die != nil do
            Process.exit(must_die, :kill)
        end
        Process.sleep(150)
        snd_guard_ID = spawn(fn -> sender_guardian(floor_table) end)
        Process.register(snd_guard_ID, :sender_guardian)

        snd_guard_ID 
    end

    def init_dummy_master() do
        must_die = Process.whereis(:master)
        if must_die != nil do
            Process.exit(must_die, :kill)
        end
        Process.sleep(500)
        dummy = spawn(fn -> dummy_master() end)
        Process.register(dummy, :master)

        dummy        
    end

    # MODULE PROCESSES

    def order_checker(old_orders, floor_table) when is_list(old_orders) do
        Network.send_data_inside_node(:order_checker, :checker_guardian, {:ping, Time.to_iso8601(Time.utc_now)})

        checkerSleep = 250

        # Update order list by reading all HW order buttons
        new_orders = check_4_orders(floor_table)
        orders = old_orders++new_orders
        #orders = old_orders++check_4_orders

        #---TEST CODE - REMOVE BEFORE LAUNCH---#
        if new_orders != [] do
            IO.inspect("Recieved #{inspect length(new_orders)} new orders",label: "orderChecker")
            Process.sleep(checkerSleep)
        end

        # Check for request from sender. If there is, send order list and recurse with reset list
        receive do
            {:panel, {_message_ID, :gibOrdersPls}} ->
                Network.send_data_inside_node(:order_checker, :panel, {:newOrders, orders})

                #---TEST CODE - REMOVE BEFORE LAUNCH---#
                #IO.inspect("Received send request. Sent #{inspect length(orders)} orders" ,label: "orderChecker")
                #Process.sleep(checkerSleep)
                #--------------------------------------#
                order_checker([], floor_table)
                
            {_sender, {_messageID, {:special_delivery, special_orders}}} ->
                order_checker(orders++special_orders, floor_table)
            after
                0 -> :ok
        end

        # If no send request, requrse with current list (output buffer)
        order_checker(orders, floor_table)
    end

    def order_sender(floor_table, send_ID, outgoing_orders) when is_list(outgoing_orders) do
        Network.send_data_inside_node(:panel, :sender_guardian, {:ping, Time.to_iso8601(Time.utc_now)})
        ackTimeout = 800
        checkerTimeout = 1000

        # If the order matrix isnt empty ...
        if outgoing_orders != [] do
            # ... send orders to all masters on network, and send cab orders to local elevator
            Network.send_data_to_all_nodes(:panel, :master, {outgoing_orders, send_ID})
            Network.send_data_inside_node(:panel, :elevator, Order.extract_cab_orders(outgoing_orders))

            # ... and wait for an ack
            receive do
                {:master, {_message_ID, {:ack, sentID}}} ->
                    # When ack is recieved for current send_ID, send request to checker for latest order matrix
                    if sentID >= (send_ID) do
                        Network.send_data_inside_node(:panel, :order_checker, :gibOrdersPls)
                        IO.inspect("Received ack on SendID #{sentID}", label: "orderSender")   # TEST CODE
                        receive do
                            # When latest order matrix is received, recurse with new orders and iterated send_ID
                            {:order_checker, {_messageID, {:newOrders, updated_orders}}} ->
                                order_sender(floor_table, send_ID+1, updated_orders)
                                after
                                    checkerTimeout -> IO.inspect("OrderSender timed out waiting for orders from orderChecker[1]", label: "Error")# Send some kind of error, "no response from order_checker" # TEST CODE
                                    order_sender(floor_table, send_ID, outgoing_orders)
                        end
                    else
                        # (If the ack is too old)
                        IO.inspect("OrderSender timed out waiting for ack on Send_ID #{send_ID} [else]", label: "Error")
                        order_sender(floor_table, send_ID, outgoing_orders)
                    end
                # If no ack is received after 'ackTimeout' number of milliseconds: Recurse and repeat
                after
                    ackTimeout -> IO.inspect("OrderSender timed out waiting for ack on Send_ID #{send_ID} [after]", label: "Error")
                    order_sender(floor_table, send_ID, outgoing_orders)
            end

        else
            # If order matrix is empty, send request to checker for latest orders. Recurse with those (but same sender ID)
            Network.send_data_inside_node(:panel, :order_checker, :gibOrdersPls)
            receive do
                {:order_checker, {_messageID, {:newOrders, updated_orders}}} ->
                    order_sender(floor_table, send_ID, updated_orders)
                    after
                        checkerTimeout -> IO.inspect("OrderSender timed out waiting for orders from orderChecker [2]", label: "Error")# Send some kind of error, "no response from order_checker"
                        order_sender(floor_table, send_ID, outgoing_orders)
            end
        end

    end

    defp checker_guardian(floor_table, missed_pings \\ 0, prev_ping \\ "0") do
        Process.sleep(100)
        buddy_ID = Process.whereis(:panel)
        if buddy_ID != nil do
            Process.link(buddy_ID)
        else
            IO.inspect("Watch out! Checker Guardian couldn't link with sender", label: "Error")
        end

        if missed_pings > 3 do

            IO.inspect("Checker missed out on #{inspect missed_pings} pings and is reinitialized", label: "Checker Guardian")
            init_checker(floor_table)

        else
            receive do
                {:order_checker, {_message_ID, {:ping, stamp}}} ->
                    if stamp>prev_ping do
                        checker_guardian(floor_table, 0 , stamp)
                    else
                        IO.inspect("Checker missed out on ping", label: "Checker Guardian")
                        checker_guardian(floor_table, missed_pings + 1, prev_ping)
                    end
            after
                200 -> 
                    IO.inspect("Checker missed out on ping", label: "Checker Guardian")
                    checker_guardian(floor_table, missed_pings + 1, prev_ping)
            end
        end      
    end

    defp sender_guardian(floor_table, missed_pings \\ 0, prev_ping \\ "0") do
        Process.sleep(100)
        buddy_ID = Process.whereis(:order_checker)
        if buddy_ID != nil do
            Process.link(buddy_ID)
        else
            IO.inspect("Watch out! Sender Guardian couldn't link with sender", label: "Error")
        end

        if missed_pings > 3 do

            IO.inspect("Sender missed out on #{inspect missed_pings} pings and is reinitialized", label: "Sender Guardian")
            init_sender(floor_table)

        else
            receive do
                {:panel, {_message_ID, {:ping, stamp}}} ->
                    if stamp>prev_ping do
                        sender_guardian(floor_table, 0 , stamp)
                    else
                        IO.inspect("Sender missed out on ping", label: "Sender Guardian")
                        sender_guardian(floor_table, missed_pings + 1, prev_ping)
                    end
            after
                1400 -> 
                    IO.inspect("Sender missed out on ping", label: "Sender Guardian")
                    sender_guardian(floor_table, missed_pings + 1, prev_ping)
            end
        end
    end

    # WORKHORSE FUNCTIONS

    def hardware_order_checker(floor, type) do
        try do
            if Driver.get_order_button_state(floor, type) == 1 do
                # TODO: Replace Time.utc_now() with wrapper func from Timer module
                order = struct(Order, [order_id: Time.utc_now(), order_type: type, order_floor: floor])
            else
                order = []
            end            

        catch
            :exit, reason -> 
                #IO.inspect("EXIT: #{inspect reason}\n Check if panel is connected to elevator HW.", label: "HW Order Checker")
                order = []
        end
        
    end

    def check_order(orderType, table \\ Enum.to_list(0..@num_floors-1)) do
        sendor_states = Enum.map(table, fn x -> hardware_order_checker(x, orderType) end)
        orders = Enum.reject(sendor_states, fn x -> x == [] end)
    end

    def check_4_orders(table \\ Enum.to_list(0..@num_floors-1)) do
        orders = check_order(:hall_up, table)++check_order(:hall_down, table)++check_order(:cab, table)
    end

    ### TEST CODE ###

    def annihilate() do
        checkerID = Process.whereis(:order_checker)
        senderID = Process.whereis(:panel)
        if checkerID != nil do
            Process.exit(checkerID, :kill)
        end
        if senderID != nil do
            Process.exit(senderID, :kill)
        end
    end

    def dummy_master() do
        Process.sleep(1000)
        receive do
            {_sender_id, {_message_id, {orders, sendID}}} ->
                Network.send_data_inside_node(:master, :panel, {:ack, sendID})
                Lights.set_order_lights(orders)
                after
                    0 -> :ok
        end
        dummy_master()
    end

end