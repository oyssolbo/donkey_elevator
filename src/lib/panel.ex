# Should one import, or should one try to use require inside the Module? What is the difference here?

#import Driver
import Matriks

defmodule Panel do
    @state_map  %{:on => true, :off => false}

    def init(mid, eid) do
        checkerID = spawn(fn -> order_checker(Matriks.false_order_matrix) end)
        senderID = spawn(fn -> order_sender(mid, eid, checkerID, 0, Matriks.false_order_matrix) end)
        {senderID, checkerID}
    end


    defp order_checker(old_order_matrix) do

        # Update order matrix by reading all HW order buttons
        [new_up, new_down, new_cab] = [up_checker, down_checker, cab_checker]
        new_order_matrix = Matriks.from_list([new_up, new_down, new_cab])
        updated_matrix = Matriks.orderMatrixOR(old_order_matrix, new_order_matrix)

        # Check for request from sender. If there is, send order matrix and recurse with reset matrix
        receive do
            {:gibOrdersPls, senderAddr} ->
                send(senderAddr, {:order_checker, updated_matrix})
                order_checker(Matriks.false_order_matrix)
            after
                0 -> :ok
        end

        # If no send request, requrse with current matrix (output buffer)
        order_checker(updated_matrix)
    end

    defp order_sender(mid, eid, checker_addr, sendID, outgoing_matrix) do

        # If the order matrix isnt empty ...
        if outgoing_matrix != Matriks.false_order_matrix do

            # ... send the respective  orders to master and elevator
            # Should have an enum or variable indicating idx for master and idx for elevator
            send(mid, {self(), :newOrders, sendID, [Matriks.to_list(outgoing_matrix[0]), Matriks.to_list(outgoing_matrix[1])]})
            send(eid, {self(), :newOrders, sendID, Matriks.to_list(outgoing_matrix[2])})

            # ... and wait for an ack
            receive do
                {:ack, from, sentID} ->
                    # When ack is recieved, send ack back. Send request to checker for latest order matrix
                    """
                    Shouldn't really be necessary! See what I wrote on miro
                    """
                    send(from, {:ack, sentID})
                    send(checker_addr, {:gibOrdersPls, self()})
                    receive do
                        # When latest order matrix is received, recurse with new orders and iterated sendID
                        {:order_checker, updated_matrix} ->
                            order_sender(mid, eid, checker_addr, sendID+1, updated_matrix)
                    end
                # If no ack is received after 1.5 sec: Recurse and repeat
                after
                    # Should have the timer as a standard-value
                    1500 -> order_sender(mid, eid, checker_addr, sendID, outgoing_matrix)
            end

        else
            # If order matrix is empty, send request to checker for latest orders. Recurse with those (but same sender ID)
            send(checker_addr, {:gibOrdersPls, self()})
                    receive do
                        {:order_checker, updated_matrix} ->
                            order_sender(mid, eid, checker_addr, sendID, updated_matrix)
                    end
        end

    end


    defp up_checker do
        [floor1, floor2, floor3, floor4] = [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])]
    end

    defp down_checker do
        [floor1, floor2, floor3, floor4] = [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])]
    end

    defp cab_checker do
        [floor1, floor2, floor3, floor4] = [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])]
    end

    defp order_matrix_updater(mn, mo) do
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
