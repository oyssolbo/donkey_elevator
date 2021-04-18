defmodule Storage do
    @moduledoc """
    Rudamentary file storage module. Allows (lists of) Order structs to be written to and
    read from a txt-file. The module is implemented such that any previously saved data
    is overwritten!
    """

    require Logger
    require Order

    @doc """
    Writes strings to a txt-file, default name "save_data.txt". Data is encoded using Poison,
    and overwrites whatever was on the file from before.
    """
    def write(data, fileName \\ "save_data.txt") do
        {ereport, textData} = Poison.encode(data)
        if ereport != :ok do
            Logger.error("Encode operation failed - write aborted")
        else
            result = File.write(fileName, textData)
        end
    end

    @doc """
    Reads from a txt-file, default name "save_data.txt". Assumes the data is a list of Poison-encoded
    Order-structs, and will attempt to reconstruct said data. If an error occurs, the function returns
    an empty list. Otherwise, it returns a list containing old orders
    """
    def read(fileName \\ "save_data.txt") do
        try do
            {report, result} = File.read(fileName)
            {dreport, map_list} = Poison.decode(result)
            if report != :ok or dreport != :ok do
                Logger.error("Read failed - check data integrity")
                []
            else
                structify_maplist(map_list)
            end

        catch
            :error, reason ->
                Logger.error("Reading from file failed due to #{Kernel.inspect(reason)}")
                []
            :exit, reason ->
                Logger.error("Reading from file triggered exit due to #{Kernel.inspect(reason)}")
                []
            _->
                Logger.error("Reading from file failed due to unknown error")
                []
        end
    end

    @doc """
    Creates an order from a list of values, corrected for the mistakes made by Poison decode.
    (Poison decodes atoms into strings)
    """
    defp order_from_value_list(lst)
    when is_list(lst)
    do
        elev = Enum.at(lst, 0)
        floor = Enum.at(lst, 1)
        id = Time.from_iso8601!(Enum.at(lst, 2))
        type = String.to_atom(Enum.at(lst, 3))

        order = struct(Order, [order_id: id, order_type: type, order_floor: floor, delegated_elevator: elev])
    end

    @doc """
    Turns list of order maps into list of order structs.
    """
    defp structify_maplist([head | tail])
    do
        vals = Map.values(head)
        [order_from_value_list(vals)] ++ structify_maplist(tail)
    end
    defp structify_maplist([]) do
        []
    end

end
