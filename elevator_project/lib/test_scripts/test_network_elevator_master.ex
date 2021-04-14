defmodule NetworkTest do

  # Should probably start init as a new process, will fix tomorrow
  def init()
  do
    Driver.start_link([])
    #Network.init_node_network()
    Elevator.start_link([])
    Master.start_link([])
    Panel.start_link([])
    Lights.start_link([])
  end

  def receive_thread()
  do
    receive do
      {_master, _from_node, message_id, _test_data} ->
        case Network.receive_ack(message_id) do
          {:ok, _receiver_id}->
            IO.puts("Ack received")
          {:no_ack, :no_id}->
            IO.puts("Ack not received")
        end
    end
    receive_thread()
  end

  def init_receive()
  do
    spawn_link(fn -> receive_thread() end) |>
      Process.register(:master_receive)
  end

  def send_data_wait_for_ack() do
    message_id = Network.send_data_all_nodes(:tester, :master_receive, :test_data)
    Network.send_data_all_nodes(:test_function, :master_receive, {message_id, :ack})
  end

end
