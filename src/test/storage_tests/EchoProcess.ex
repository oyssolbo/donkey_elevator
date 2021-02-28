defmodule EchoProcess do
    # A function will always return the last statement in a function
    def start do    # So "start" will return PID from spawn
        spawn(fn -> echo_process() end)   # "spawn(echo_process)" would call echo_process and spawn whatever it returns...
    end

    defp echo_process do    # defp makes the function private
        receive do
            {from, message} -> IO.puts("\"" <> message <> "\"" <> " was heard as a distant echo.")
            #{:debug, debug_message} -> IO.puts(debug_message)
            # Process will now iterate through mailbox and see if it can find
            # some message that it can pattern match with, into IO.puts
            # Order of these lines indicate priority; it takes whatever matches first
            send(from, ~s(EchoProcess thought") <> message <> ~s(" was a lame thing to send to an echo, and calls you a little bitch.))
            echo_process()
        end
    end

    def yell(echo_process, message) do
        send(echo_process, {self(), message})
    end

end