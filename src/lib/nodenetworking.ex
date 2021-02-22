defmodule NodeInit do
  @moduledoc """
  Module for initializing a node on the system

  Lot of creditation to Jostein Løwer here...
  """

  @doc """
  Credit to Jostein Løwer: https://github.com/jostlowe/kokeplata/blob/master/lib/networkstuff.ex (22.02.21)

  Boots the node with a given tick-time
  """
  def boot_node(node_name, tick_time \\ 15000) do
    try do
      ip = get_my_ip() |> ip_to_string()
      full_name = node_name <> "@" <> ip
      Node.start(String.to_atom(full_name), :longnames, tick_time)
      #Node.set_cookie(:elevator_project)
      IO.puts("Node '#{node_name}' is booted and ready to go")
    rescue
      e in RuntimeError -> IO.puts("An error occurred: " <> e.message)
      e in _ -> IO.puts("Unknown error occured")
      IO.puts("Shutting down node '#{node_name}'")
      # Raise an error such that the supervisor can handle it
      :error
    end
  end


  @doc """
  Credit to Jostein Løwer: https://github.com/jostlowe/kokeplata/blob/master/lib/networkstuff.ex (22.02.21)

  Tries to find the node's ip-address
  """
  def get_my_ip(counter \\ 0) when counter < 11 do
    {:ok, socket} = :gen_udp.open(6791, [active: :false, broadcast: :true, reuseaddr: :true])
    :ok = :gen_udp.send(socket, {255, 255, 255, 255}, 6791, "Test packet")

    ip = case :gen_udp.recv(socket, 100, 1000) do
        {:ok, {ip, _port, _data}} ->
          ip
        {:error, _} ->
          Process.sleep(50)
          get_my_ip(counter + 1)
      end

    :gen_udp.close(socket)
    ip
  end

  @doc """
  Credit to Jostein Løwer: https://github.com/jostlowe/kokeplata/blob/master/lib/networkstuff.ex (22.02.21)

  Converts an ip-address into a bytestring
  """
  def ip_to_string(ip) do
    :inet.ntoa(ip) |> to_string()
  end


  # Credit to Jostein Løwer. Same link as above
  def all_nodes() do
    case [Node.self | Node.list] do
      [:'nonode@nohost'] -> {:error, :node_not_running}
      nodes -> nodes
    end
  end
end


defmodule HeatNode do
  def init() do
    NodeInit.boot_node("heat_creator")
    active_nodes = NodeInit.all_nodes()
    listen()
  end

  def listen() do
    case NodeInit.all_nodes() do
      {:error, :node_not_running} ->
          Process.sleep(50)
        nodes ->
          create_connection(nodes)
    end
    listen()
  end

  def create_connection(nodes) when nodes |> is_list do
    :ok
  end
end

defmodule ColdNode do
  def init() do
    NodeInit.boot_node("cold_node")
    active_nodes = NodeInit.all_nodes()
    listen()
  end

  def listen() do
    case NodeInit.all_nodes() do
      {:error, :node_not_running} ->
          Process.sleep(50)
        nodes ->
          create_connection(nodes)
    end
    listen()
  end

  def create_connection(nodes) when nodes |> is_list do
    :ok
  end
end
