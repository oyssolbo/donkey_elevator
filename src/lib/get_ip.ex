defmodule GetIP do
  @moduledoc """
  Module giving basic functions for using networking

  Entire module inspired by Jostein Løwer

  Credit to: Jostein Løwer, NTNU (2019)
  Link: https://github.com/jostlowe/kokeplata/blob/master/lib/networkstuff.ex
  """

  @broadcast_address {255, 255, 255, 255}
  @init_port 6789
  @num_tries 5


  @doc """
  Function that hopefully returns the IP-address of the system
  """
  def get_my_ip(port \\ @init_port) do
    case UDP.open_connection(port, [active: false, broadcast: true]) do
      {:ok, socket} ->
        UDP.send_data(socket, @broadcast_address, port, "Test")

        case UDP.receive_data(socket) do
          {:recv, {ip, _port, _data}} ->
            ip
          {:error, _} ->
            {:error, :could_not_get_ip}
        end

        UDP.close_socket(socket)

        {:nil, _} ->
          if port - @init_port < @num_tries do
            get_my_ip(port + 1)
          else
            {:error, :could_not_get_ip}
          end
    end
  end


  @doc """
  Formats an ip-address to a bytestring
  """
  def ip_to_string(ip) do
    :inet.ntoa(ip) |> to_string()
  end
end
