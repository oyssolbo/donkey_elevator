require Driver
require UDP
import Matriks

""" Order-struct
Example
    l1 = [ID-1, ID-2]
    l2 = [:up, :down]
    l3 = [1, 4]

    orders = Order.zip(l1, l2, l3)

Syntax
    @Order{order_ID, order_type, order_floor}
"""

defmodule Panel do
    @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}
    @state_map  %{:on => 1, :off => 0}
    @direction_map %{:up => 1, :down => 255, :stop => 0}

    numFloors = 4 # Get this from config somehow
    floorTable = Enum.to_list(0..numFloors-1) # Creates an array of the floors; makes it easier to iterate through
    mySocket = nil
    #myPort = nil

    def init(mid, eid, port \\ []) do
        mySocket = UDP.open_connection(port)

        checkerID = spawn(fn -> orderChecker(Matriks.falseOrderMatrix) end)
        senderID = spawn(fn -> orderSender(mid, eid, checkerID, 0, Matriks.falseOrderMatrix) end)
        {senderID, checkerID}
    end


    defp orderChecker(---) do
        
        # Update order matrix by reading all HW order buttons
        

        # Check for request from sender. If there is, send order matrix and recurse with reset matrix
        receive do
            {:gibOrdersPls, senderAddr} ->
                
            after
                0 -> :ok
        end

        # If no send request, requrse with current matrix (output buffer)
        orderChecker(---)
    end

    defp orderSender(mid, eid, checkerAddr, sendID, outGoingMatrix) do

        # If the order matrix isnt empty ...
        if outGoingMatrix != Matriks.falseOrderMatrix do

            # ... send the respective  orders to master and elevator
            ...

            # ... and wait for an ack
            receive do
                {:ack, from, sentID} ->
                    # When ack is recieved, send request to checker for latest order matrix
                    send(checkerAddr, {:gibOrdersPls, self()})
                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated sendID
                        {:orderChecker, updatedMatrix} ->
                            orderSender(mid, eid, checkerAddr, sendID+1, updatedMatrix)
                            after
                                2000 -> # Send some kind of error, "no response from orderChecker"
                    end
                # If no ack is received after 1.5 sec: Recurse and repeat
                after
                    1500 -> orderSender(mid, eid, checkerAddr, sendID, outGoingMatrix)
            end

        else 
            # If order matrix is empty, send request to checker for latest orders. Recurse with those (but same sender ID)
            send(checkerAddr, {:gibOrdersPls, self()})
                    receive do
                        {:orderChecker, updatedMatrix} ->
                            orderSender(mid, eid, checkerAddr, sendID, updatedMatrix)
                    end
        end
     
    end


    defp upChecker do
        sensorStates = Enum.map(floorTable, fn x -> get_order_button_state(x, :hall_up) end)
    end

    defp downChecker do
        [floor1, floor2, floor3, floor4] = [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])]
    end

    defp cabChecker do
        [floor1, floor2, floor3, floor4] = [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])]
    end

    defp orderMatrixUpdater(mn, mo) do
        updated = [[mn[0][0] or mo[0][0], mn[0][1] or mo[0][1], mn[0][2] or mo[0][2], mn[0][3] or mo[0][3]],
                   [mn[1][0] or mo[1][0], mn[1][1] or mo[1][1], mn[1][2] or mo[1][2], mn[1][3] or mo[1][3]],
                   [mn[2][0] or mo[2][0], mn[2][1] or mo[2][1], mn[2][2] or mo[2][2], mn[2][3] or mo[2][3]]]
    end
end

# Driver.get_floor_sensor_state(floor, button_type) |> state
