"""
Syntax
    @Order{order_ID, order_type, order_floor}
"""

defmodule Panel do
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
        sender_ID = spawn(fn -> order_sender(checker_ID, floor_table, 0, []) end)

        # Register the processes in the local node
        Process.register(checker_ID, :order_checker)
        Process.register(sender_ID, :panel)

        #---TEST CODE---#
        dummy = spawn(fn -> dummy_master() end)
        Process.register(dummy, :master)
        #---------------#

        checker_sprvsr_init(floor_table)
        sender_sprvsr_init(floor_table)

        {checker_ID, sender_ID}
    end

    defp init_checker(floor_table) do
        must_die = Process.whereis(:order_checker)
        if must_die != nil do
            Process.exit(must_die, :kill)
        end
        checker_ID = spawn(fn -> order_checker([], floor_table) end)
        Process.register(checker_ID, :order_checker)

        checker_ID
    end

    defp init_sender(floor_table) do
        checker_ID = Process.whereis(:order_checker)
        if checker_ID == nil do
            raise "Panel error: Order_sender-initializer could not find a checker_ID"
        else
            sender_ID = spawn(fn -> order_sender(checker_ID, floor_table, 0, []) end)
            Process.register(sender_ID, :panel)

            sender_ID
        end
    end

    # SUPERVISORS
    defp checker_sprvsr(floor_table, missed_child_pings \\ 0, missed_buddy_pings \\ 0) do
        timeout = 10000
        mcp = missed_child_pings
        mbp = missed_buddy_pings

        # Check how many pings have been missed. If above 5, run init on the relevant process
        cond do
            missed_child_pings > 5 ->
                init_checker(floor_table)
            missed_buddy_pings > 5 ->
                sender_sprvsr_init(floor_table)  
            missed_buddy_pings < 6 and missed_child_pings < 6 ->
                :ok              
        end

        # Send a ping to the other supervisor to let it know you exist
        Network.send_data_inside_node(:checker_sprvsr, :sender_sprvsr, :ping)

        # Listen for ping from child process. If none is heard within Timeout, add +1 to missed_child_pings
        receive do
            {:order_checker, {_message_id, :ping}} ->
                :ok
            after
                timeout -> 
                    mcp = mcp + 1
                    IO.inspect("Timed out on ping from child", label: "Checker Supervisor")
        end        

        # Listen for ping from other supervisor. If none heard within Timeout, add +1 to missed_buddy_pings
        receive do
            {:sender_sprvsr, {_message_id, :ping}} ->
                :ok
            after
                timeout -> 
                    mbp = mbp + 1
                    IO.inspect("Timed out on ping from buddy", label: "Checker Supervisor")

        end  

        # Recurse with updated missed pings
        checker_sprvsr(floor_table, mcp, mbp)
        
    end

    defp sender_sprvsr(floor_table, missed_child_pings \\ 0, missed_buddy_pings \\ 0) do
        # Check if other supervisor exists. If it doesnt, spawn it, and send it a ping
        timeout = 10000
        mcp = missed_child_pings
        mbp = missed_buddy_pings

        # Check how many pings have been missed. If above 5, run init on the relevant process
        cond do
            missed_child_pings > 5 ->
                init_sender(floor_table)
            missed_buddy_pings > 5 ->
                checker_sprvsr_init(floor_table)  
            missed_buddy_pings < 6 and missed_child_pings < 6 ->
                :ok               
        end

        # Send a ping to the other supervisor to let it know you exist
        Network.send_data_inside_node(:sender_sprvsr, :checker_sprvsr, :ping)

        # Listen for ping from child process. If none is heard within Timeout, add +1 to missed_child_pings
        receive do
            {:panel, {_message_id, :ping}} ->
                :ok
            after
                timeout -> 
                    mcp = mcp + 1
                    IO.inspect("Timed out on ping from child", label: "Sender Supervisor")
        end        

        # Listen for ping from other supervisor. If none heard within Timeout, add +1 to missed_buddy_pings
        receive do
            {:checker_sprvsr, {_message_id, :ping}} ->
                :ok
            after
                timeout -> 
                    mbp = mbp + 1
                    IO.inspect("Timed out on ping from buddy", label: "Sender Supervisor")
        end  

        # Recurse with updated missed pings
        sender_sprvsr(floor_table, mcp, mbp)
        
    end
    # defp checker_sprvsr(floor_table) do
    #     # Check if other supervisor exists. If it doesnt, spawn it, and send it a ping
    #     buddy = Process.whereis(:sender_sprvsr)
    #     if buddy == nil do
    #         sender_sprvsr_init(floor_table)
    #     else
    #         send(buddy, {:checker_sprvsr, :ping})
    #     end

    #     # Check if order_checker exists. If it doesnt, initialize it.
    #     child = Process.whereis(:order_checker)
    #     if child == nil do
    #         init_checker(floor_table)
    #     end

    #     checker_sprvsr(floor_table)      
        
    # end

    # defp sender_sprvsr(floor_table) do
    #     # Check if other supervisor exists. If it doesnt, spawn it, and send it a ping
    #     buddy = Process.whereis(:checker_sprvsr)
    #     if buddy == nil do
    #         checker_sprvsr_init(floor_table)
    #     else
    #         send(buddy, {:sender_sprvsr, :ping})
    #     end

    #     # Check if order_checker exists. If it doesnt, initialize it.
    #     child = Process.whereis(:panel)
    #     if child == nil do
    #         init_sender(floor_table)
    #     end

    #     sender_sprvsr(floor_table) 
    # end

    defp checker_sprvsr_init(floor_table) do
        fraudster = Process.whereis(:checker_sprvsr)
        if fraudster != nil do
            Process.exit(fraudster, :kill)
        end

        its_id = spawn(fn -> checker_sprvsr(floor_table) end)
        Process.register(its_id, :checker_sprvsr)
        its_id
    end

    defp sender_sprvsr_init(floor_table) do
        fraudster = Process.whereis(:sender_sprvsr)
        if fraudster != nil do
            Process.exit(fraudster, :kill)
        end

        its_id = spawn(fn -> sender_sprvsr(floor_table) end)
        Process.register(its_id, :sender_sprvsr)
        its_id
    end

    # MODULE PROCESSES

    defp order_checker(old_orders, floor_table) when is_list(old_orders) do
        Network.send_data_inside_node(:order_checker, :checker_sprvsr, :ping)

        checkerSleep = 3000 # PART OF TEST CODE - REMOVE BEFORE LAUNCH

        # Update order list by reading all HW order buttons
        new_orders = check_4_orders(floor_table)
        orders = old_orders++new_orders
        #orders = old_orders++check_4_orders

        #---TEST CODE - REMOVE BEFORE LAUNCH---#
        if new_orders != [] do
            IO.inspect("Recieved new order, #{inspect length(new_orders)}",label: "orderChecker")
            Process.sleep(checkerSleep)
        end

        # Check for request from sender. If there is, send order list and recurse with reset list
        receive do
            {:gibOrdersPls, sender_addr} ->
                send(sender_addr, {:order_checker, orders})

                #---TEST CODE - REMOVE BEFORE LAUNCH---#
                IO.inspect("Received send request. Sent orders #{inspect length(orders)}" ,label: "orderChecker")
                Process.sleep(checkerSleep)
                #--------------------------------------#
                order_checker([], floor_table)
                
            {:special_delivery, special_orders} ->
                order_checker(orders++special_orders, floor_table)
            after
                0 -> :ok
        end

        # If no send request, requrse with current list (output buffer)
        order_checker(orders, floor_table)
    end

    defp order_sender(checker_addr, floor_table, send_ID, outgoing_orders) when is_list(outgoing_orders) do
        Network.send_data_inside_node(:panel, :checker_sprvsr, :ping)
        ackTimeout = 5000
        checkerTimeout = 8000

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
                        send(checker_addr, {:gibOrdersPls, self()})
                        IO.inspect("Received ack on #{sentID}", label: "orderSender")   # TEST CODE
                    end
                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated send_ID
                        {:order_checker, updated_orders} ->
                            order_sender(checker_addr, floor_table, send_ID+1, updated_orders)
                            after
                                checkerTimeout -> IO.inspect("OrderSender timed out waiting for orders from orderChecker", label: "Error")# Send some kind of error, "no response from order_checker" # TEST CODE
                                #init_checker(floor_table) # Assume order_checker has died. Reinitialize it
                    end
                # If no ack is received after 'ackTimeout' number of milliseconds: Recurse and repeat
                after
                    ackTimeout -> IO.inspect("OrderSender timed out waiting for ack on Send_ID #{send_ID}", label: "Error")
                    order_sender(checker_addr, floor_table, send_ID, outgoing_orders)
            end

        else
            # If order matrix is empty, send request to checker for latest orders. Recurse with those (but same sender ID)
            send(checker_addr, {:gibOrdersPls, self()})
            receive do
                {:order_checker, updated_orders} ->
                    order_sender(checker_addr, floor_table, send_ID, updated_orders)
                    after
                        checkerTimeout -> IO.inspect("OrderSender timed out waiting for orders from orderChecker", label: "Error")# Send some kind of error, "no response from order_checker"
                        #init(self(), floor_table) # Assume order_checker has died. Reinitialize it
                        order_sender(checker_addr, floor_table, send_ID, outgoing_orders)
            end
        end

    end

    # WORKHORSE FUNCTIONS

    def hardware_order_checker(floor, type) do
        if Driver.get_order_button_state(floor, type) == 1 do
            # TODO: Replace Time.utc_now() with wrapper func from Timer module
            order = struct(Order, [order_id: Time.utc_now(), order_type: type, order_floor: floor])
        else
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

    def dummy_hardware_order_checker(floor, type) do
        num = :rand.uniform(10)
        ordr = []
        if num > 4 do
            ordr = Order.gib_rnd_order(floor,type)
        end
    end

    def dummy_master() do
        Process.sleep(1000)
        receive do
            {sender_id, {message_id, {orders, sendID}}} ->
                send(sender_id, {:ack, sendID})
                Lights.set_order_lights(orders)
                after
                    0 -> :ok
        end
        dummy_master()
    end

end
