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
    require Network
    require Order
    require Logger

    # use GenServer


    @num_floors Application.fetch_env!(:elevator_project, :project_num_floors)
    @ack_timeout Application.fetch_env!(:elevator_project, :panel_ack_timeout)
    @checker_timeout Application.fetch_env!(:elevator_project, :panel_checker_timeout)
    @checker_sleep Application.fetch_env!(:elevator_project, :panel_checker_sleep)

    # floor_table: Array of the floors; makes it easier to iterate through

    # INITIALIZATION FUNTIONS

    @doc """
    start_link is the true init

    Initializes the panel module by spawning the 'order checker' and 'order sender' processes,
    and registering them at the local node as :order_checker and :panel respectively.

    Returns a tuple with their PIDs.

    init(sender_ID, floor_table) will only initialize the checker process and is used by the sender
    in the case that the checker stops responding.
    """

    # def start_link(init_arg \\ [])
    # do
    #     server_opts = [name: :panel_module]
    #     GenServer.start_link(__MODULE__, init_arg, server_opts)
    # end

    def init(floor_table \\ Enum.to_list(0..@num_floors-1)) do

        checker_ID = spawn(fn -> order_checker([], floor_table) end)
        sender_ID = spawn(fn -> order_sender(floor_table, 0, []) end)

        # Register the processes in the local node
        Process.register(checker_ID, :order_checker)
        Process.register(sender_ID, :panel)


        {:ok, checker_ID, sender_ID}
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
    defp order_checker(old_orders, floor_table) when is_list(old_orders) do

        checkerSleep = @checker_sleep

        # Update order list by reading all HW order buttons
        new_orders = check_4_orders(floor_table)
        orders = old_orders++new_orders
        #orders = old_orders++check_4_orders

        #---TEST CODE ---#
        if new_orders != [] do
            IO.inspect("Recieved #{inspect length(new_orders)} new orders",label: "orderChecker")
            Process.sleep(checkerSleep)
        end
        #----------------#

        # Check for request from sender. If there is, send order list and recurse with reset list
        receive do
            {:panel, _node, _message_ID, :gibOrdersPls} ->
                Network.send_data_inside_node(:order_checker, :panel, orders)

                order_checker([], floor_table)

            {_sender, _node, _messageID, {:special_delivery, special_orders}} ->
                order_checker(orders++special_orders, floor_table)
            after
                0 -> :ok
        end

        # If no send request, requrse with current list (output buffer)
        order_checker(orders, floor_table)
    end

    defp order_sender(floor_table, send_ID, outgoing_orders) when is_list(outgoing_orders) do
        ackTimeout = @ack_timeout
        checkerTimeout = @checker_timeout

        # If the order matrix isnt empty ...
        if outgoing_orders != [] do
            # ... send orders to all masters on network, and send cab orders to local elevator
            Logger.info("sending data")
            IO.inspect(outgoing_orders)
            ack_message_id_master = Network.send_data_all_nodes(:panel, :master_receive, outgoing_orders)
            ack_message_id_elevator = Network.send_data_inside_node(:panel, :elevator_receive, Order.extract_orders(:cab, outgoing_orders))

            # ... and wait for an ack
            receive do
                {_sender_id, _node, _messageID, {ack_message_id_elevator, :ack}} ->
                    # When ack is recieved for current send_ID, send request to checker for latest order matrix
                    Network.send_data_inside_node(:panel, :order_checker, :gibOrdersPls)
                    IO.inspect("Received ack from elevator")   # TEST CODE

                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated send_ID
                        {:order_checker, _node, _messageID, updated_orders} ->
                            order_sender(floor_table, send_ID+1, updated_orders)
                            after
                                checkerTimeout ->
                                Logger.info("Timeout from order checker")
                                 #IO.inspect("OrderSender timed out waiting for orders from orderChecker[1]", label: "Error")# Send some kind of error, "no response from order_checker" # TEST CODE
                                order_sender(floor_table, send_ID, outgoing_orders)
                    end
                # If no ack is received after 'ackTimeout' number of milliseconds: Recurse and repeat
                after
                    ackTimeout ->
                        IO.inspect("OrderSender timed out waiting for ack", label: "Warning")
                        order_sender(floor_table, send_ID, outgoing_orders)
            end

        else
            # If no orders, send request to checker for latest orders. Recurse with those (but same sender ID)

            Network.send_data_inside_node(:panel, :order_checker, :gibOrdersPls)
            receive do
                {:order_checker, _node, _messageID, updated_orders} ->
                    order_sender(floor_table, send_ID, updated_orders)
                after
                    checkerTimeout -> #IO.inspect("OrderSender timed out waiting for orders from orderChecker [2]", label: "Error")# Send some kind of error, "no response from order_checker"
                    Logger.info("Did not get reply from order checker")
                    order_sender(floor_table, send_ID, outgoing_orders)
            end
        end

    end

    # WORKHORSE FUNCTIONS

    def hardware_order_checker(floor, type) do
        try do
            if Driver.get_order_button_state(floor, type) == 1 do
                order = struct(Order, [order_id: Timer.get_utc_time(), order_type: type, order_floor: floor])
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

    # ### TEST CODE ###

    # def annihilate() do
    #     checkerID = Process.whereis(:order_checker)
    #     senderID = Process.whereis(:panel)

    #     if checkerID != nil do
    #         Process.exit(checkerID, :kill)
    #     end
    #     if senderID != nil do
    #         Process.exit(senderID, :kill)
    #     end
    # end

    # def dummy_master() do
    #     Process.sleep(1000)
    #     receive do
    #         {sender_id, {_message_id, {orders, sendID}}} ->
    #             send(sender_id, {:ack, sendID})
    #             Lights.set_order_lights(orders)
    #             after
    #                 0 -> :ok
    #     end
    #     dummy_master()
    # end





end
