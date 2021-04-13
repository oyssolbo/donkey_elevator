#import Matriks

defmodule Storage do

    require Order

    @moduledoc """
    Rudamentary file storage module. Allows sent data to be written to file, or read from it.
    Use atoms :write or :read to tell it what you want. Be sure to include MasterID and versionID
    as arguments.
    For write, returns IDs of attempted write, as well as whether it succeeded (as message).
    Work in progress; currently overwrites previous data upon write. Does not format data before
    returning a read request. Also doesnt do any sort of duplication or error checking, cuz holy
    shit is data manipulation in Elixir asinine.
    """
    @doc """
    Writes to or reads from file.
    ## Example
        Write:
      iex> strg = Storage.init
      send(strg, {self(), :write, "This shall be written.", <masterID>, <versionID>})
        Read:
      send(strg, {self(), :read})
    """

    def write(data, fileName \\ "save_data.txt") do
        textData = Poison.encode!(data)
        result = File.write(fileName, textData)
    end

    def read(fileName \\ "save_data.txt") do
        result = File.read!(fileName)   #Beware! read! embeds errors into results, without error messages
        map_list = Poison.decode!(result)
        orders = structify_maplist(map_list)
    end

    @doc """
    Creates an order from a list of values, corrected for the mistakes made by Poison decode.
    """
    defp order_from_value_list(lst) when is_list(lst) do
        elev = Enum.at(lst, 0)
        floor = Enum.at(lst, 1)
        id = Time.from_iso8601!(Enum.at(lst, 2))
        type = String.to_atom(Enum.at(lst, 3))
        
        order = struct(Order, [order_id: id, order_type: type, order_floor: floor, delegated_elevator: elev])
    end

    @doc """
    Turns list of order maps into list of order structs.
    """
    defp structify_maplist([head | tail]) do

        vals = Map.values(head)

        orders = [order_from_value_list(vals)] ++ structify_maplist(tail)
        
    end

    defp structify_maplist([]) do
        []
    end

@doc """
Notes:
File.write accepts only(?) _a_ string as argument, so process all data before passing.
As far as I know, only Enum.join can consistently combine various elements of a _list_ together as a string
without giving you errors and bad_args up the ass. If you wanna write a tuple, convert to list first; tuple.to_list()
Also, the '<>' operator for combining strings doesnt like working with numbers. To avoid enforcing 'Master ID' etc
be converted to strings before sending, I just pass the whole damn thing through Enum.join() (it seems to eat everything).
Bigbrain syntax for converting to string: "#/{inspect <var>}", without the /
"""
# Enum.at(<list>, index)
# Kernel.elem(tuple, index)
# Kernel.to_string(term)
# Map.values(<map>) >> List of values
# Map.from_struct(<struct>)
# String.split()
# dataMap = Enum.map(data, fn x -> Map.from_struct(x) end)


# order |> Map.from_struct() |> Map.values() |> valueList

    # Data structure, in:   {ext_orders, int_orders, masterID, versID}
    #   Extern order:       {bool_orderMatrix}
    #   Intern order:       {maskinID, boolOrderVector}
    #   Intern order_map:      {maskinID_vec, boolOrderMatrix}

    # Data structure, out:  {ext_orders, int_orders, masterID, versID}
    #   Extern order_map:      {bool_orderMatrix, directionParity, floorParity}
    #   Intern order:       {maskinID, boolOrderVector}
    #   Intern order_map:      {maskinID_vec, maskinID_checksum, boolOrderMatrix, intVec_directionParity, intVec_floorParity}

end
