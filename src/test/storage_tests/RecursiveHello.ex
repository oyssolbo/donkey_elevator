defmodule RecursiveHello do
    def say_hello(depth) do  
        if depth > 0 do
            IO.puts("Hello")
            Process.sleep(500)
            say_hello(depth - 1)
        else 
            IO.puts("im die. thank you forever")
        end
    end
end