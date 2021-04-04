defmodule Panel_X.Supervisor do
    use Supervisor

    def start_link(init_args) do
        Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
    end


    @impl true
    def init(init_args) do
        children = [
            %{
                id: "order_checker",
                start: {Panel_X, :init_checker, [init_args]}
            },
            %{
                id: "panel",
                start: {Panel_X, :init_sender, [init_args]}
            },
            %{
                id: "dummy_master",
                start: {Panel_X, :init_dummy_master, []}
            }
        ]

        Supervisor.init(children, strategy: :one_for_one)
    end
    
end