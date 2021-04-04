defmodule Panel_X.Supervisor do
    use Supervisor

    def start_link(init_args) do
        Supervisor.start_link(__MODULE__, :ok init_args)
    end


    @impl true
    def init(:ok) do
        children = [
        
        ]

        Supervisor.init(children, strategy: :one_for_one)
    end
    
end