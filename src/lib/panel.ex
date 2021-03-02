#import Driver
import Matriks

defmodule Panel do
    @state_map  %{:on => true, :off => false}
    
    def init(mid, eid) do
        checkerID = spawn(fn -> orderChecker(Matriks.falseOrderMatrix) end)
        senderID = spawn(fn -> orderSender(mid, eid, checkerID, 0, Matriks.falseOrderMatrix) end)
        {senderID, checkerID}
    end


    defp orderChecker(oldOrderMatrix) do
        
        # Update order matrix by reading all HW order buttons
        [newUp, newDown, newCab] = [upChecker, downChecker, cabChecker]
        newOrderMatrix = Matriks.from_list([newUp, newDown, newCab])
        updatedMatrix = Matriks.orderMatrixOR(oldOrderMatrix, newOrderMatrix)

        # Check for request from sender. If there is, send order matrix and recurse with reset matrix
        receive do
            {:gibOrdersPls, senderAddr} ->
                send(senderAddr, {:orderChecker, updatedMatrix})
                orderChecker(Matriks.falseOrderMatrix)
            after
                0 -> :ok
        end

        # If no send request, requrse with current matrix (output buffer)
        orderChecker(updatedMatrix)
    end

    defp orderSender(mid, eid, checkerAddr, sendID, outGoingMatrix) do

        # If the order matrix isnt empty ...
        if outGoingMatrix != Matriks.falseOrderMatrix do

            # ... send the respective  orders to master and elevator
            send(mid, {self(), :newOrders, sendID, [Matriks.to_list(outGoingMatrix[0]), Matriks.to_list(outGoingMatrix[1])]})
            send(eid, {self(), :newOrders, sendID, Matriks.to_list(outGoingMatrix[2])})

            # ... and wait for an ack
            receive do
                {:ack, from, sentID} ->
                    # When ack is recieved, send ack back. Send request to checker for latest order matrix
                    send(from, {:ack, sentID})
                    send(checkerAddr, {:gibOrdersPls, self()})
                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated sendID
                        {:orderChecker, updatedMatrix} ->
                            orderSender(mid, eid, checkerAddr, sendID+1, updatedMatrix)
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
        [floor1, floor2, floor3, floor4] = [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])]
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

"""
    Panel order matrix (boolean):
    Floor   1  2  3  4
    UP    [ 0  0  0  0 ]
    DOWN  [ 0  0  0  0 ]
    CAB   [ 0  0  0  0 ]

    Enum.random {0, 1}

"""