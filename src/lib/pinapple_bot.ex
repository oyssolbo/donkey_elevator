#ignore this part
defmodule PineappleBot do
  def start do
    Node.start(:"foo@192.168.0.198") #this machine's IP (hostname -I for ip)
    Node.set_cookie(:cookie_name) # Throws an error for me...
    spawn(fn -> pineapple_bot() end)
  end

  #Example from elixir videos
  def pineapple_bot do
    receive do
      {from, item} ->
        IO.puts(item <> " without pineapple")
        the_return = item <> "without pineapple"
        send(from, {:from_pineapple_bot, the_return})
        pineapple_bot()

    end
  end

  def send_message(pineapple_bot, message) do
    send(pineapple_bot(), {self(), message})
  end

end


# This should be the only necesarry part
defmodule NodeModule do  #just nodes, not really servers and clients here
  def start do
    Node.start(:"hei@192.168.0.198") #this machine's IP (hostname -I for ip)
    Node.set_cookie(:cookie_name)
  end

  #TODO
  #add connects and pings
  #try sending data
end
#Use OTP, read oabout them
# documentation for erlan suck
# documentation for elixir rocks
#Supervisor watches over other processes
#Supervisors can watch over supervisors
