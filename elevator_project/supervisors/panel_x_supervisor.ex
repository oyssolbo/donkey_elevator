defmodule Panel_X.Supervisor do
    use Supervisor

    def start_link(init_args) do
        Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
    end


    @impl true
    def init(init_args) do
        children = [
            %{
                id: order_checker
                start: {Panel, init_checker, [init_args]}
            },
            %{
                id: panel
                start: {Panel, init_sender, [init_args]}
            }
        ]

        Supervisor.init(children, strategy: :one_for_one)
    end
    
end