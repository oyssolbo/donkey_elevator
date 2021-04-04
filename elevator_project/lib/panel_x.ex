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

        checker_ID = spawn(fn -> order_checker([], floor_table) end)
        sender_ID = spawn(fn -> order_sender(floor_table, 0, []) end)

        # Register the processes in the local node
        Process.register(checker_ID, :order_checker)
        Process.register(sender_ID, :panel)

        #---TEST CODE---#
        dummy = spawn(fn -> dummy_master() end)
        Process.register(dummy, :master)
        #---------------#

        {checker_ID, sender_ID}
    end

    def init_checker(floor_table) do
        must_die = Process.whereis(:order_checker)
        if must_die != nil do
            Process.exit(must_die, :kill)
        end
        checker_ID = spawn(fn -> order_checker([], floor_table) end)
        Process.register(checker_ID, :order_checker)

        checker_ID
    end

    def init_sender(floor_table) do
        must_die = Process.whereis(:panel)
        if must_die != nil do
            Process.exit(must_die, :kill)
        end
        sender_ID = spawn(fn -> order_sender(floor_table, 0, []) end)
        Process.register(sender_ID, :panel)

        sender_ID        
    end


    # MODULE PROCESSES

    def order_checker(old_orders, floor_table) when is_list(old_orders) do
        Network.send_data_inside_node(:order_checker, :checker_sprvsr, :ping)

        checkerSleep = 200

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
                #send(sender_addr, {:order_checker, orders})
                Network.send_data_inside_node(:order_checker, :panel, orders)

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
        Network.send_data_inside_node(:panel, :sender_sprvsr, :ping)
        ackTimeout = 800
        checkerTimeout = 1000

        # If the order matrix isnt empty ...
        if outgoing_orders != [] do
            # ... send orders to all masters on network, and send cab orders to local elevator
            Network.send_data_to_all_nodes(:panel, :master, {outgoing_orders, send_ID})
            Network.send_data_inside_node(:panel, :master, Order.extract_cab_orders(outgoing_orders))
            #send({:elevator, node}, {:cab_orders, :panel, self(), extract_cab_orders(orders)})

            # ... and wait for an ack
            receive do
                {:ack, sentID} ->
                    # When ack is recieved for current send_ID, send request to checker for latest order matrix
                    if sentID == send_ID do
                        #send(checker_addr, {:gibOrdersPls, self()})
                        Network.send_data_inside_node(:panel, :order_checker, :gibOrdersPls)
                        IO.inspect("Received ack on SendID #{sentID}", label: "orderSender")   # TEST CODE
                    end
                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated send_ID
                        {:order_checker, {_messageID, updated_orders}} ->
                            order_sender(floor_table, send_ID+1, updated_orders)
                            after
                                checkerTimeout -> #IO.inspect("OrderSender timed out waiting for orders from orderChecker[1]", label: "Error")# Send some kind of error, "no response from order_checker" # TEST CODE
                                order_sender(floor_table, send_ID, outgoing_orders)
                    end
                # If no ack is received after 'ackTimeout' number of milliseconds: Recurse and repeat
                after
                    ackTimeout -> IO.inspect("OrderSender timed out waiting for ack on Send_ID #{send_ID}", label: "Error")
                    order_sender(floor_table, send_ID, outgoing_orders)
            end

        else
            # If order matrix is empty, send request to checker for latest orders. Recurse with those (but same sender ID)
            #send(checker_addr, {:gibOrdersPls, self()})
            Network.send_data_inside_node(:panel, :order_checker, :gibOrdersPls)
            receive do
                {:order_checker, {_messageID, updated_orders}} ->
                    order_sender(floor_table, send_ID, updated_orders)
                    after
                        checkerTimeout -> #IO.inspect("OrderSender timed out waiting for orders from orderChecker [2]", label: "Error")# Send some kind of error, "no response from order_checker"
                        order_sender(floor_table, send_ID, outgoing_orders)
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
                IO.inspect("EXIT: #{inspect reason}\n Check if panel is connected to elevator HW.", label: "HW Order Checker")
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
            {sender_id, {_message_id, {orders, sendID}}} ->
                send(sender_id, {:ack, sendID})
                Lights.set_order_lights(orders)
                after
                    0 -> :ok
        end
        dummy_master()
    end

end
