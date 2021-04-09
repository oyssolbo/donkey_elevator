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
    """

    def write(data, fileName \\ "save_data.txt") do
        # TODO: Format order struct into string
        dataMap = Enum.map(data, fn x -> Map.from_struct(x) end)
        textData = Poison.encode!(dataMap)
        result = File.write(fileName, textData)
    end

    def read(fileName \\ "save_data.txt") do
        result = File.read!(fileName)   #Beware! read! embeds errors into results, without error messages
        ordrs = Enum.map(Poison.decode!(result), fn x -> Kernel.struct(Order, x) end)
    end

@doc """
Notes:
File.write accepts only(?) _a_ string as argument, so process all data before passing.
As far as I know, only Enum.join can consistently combine various elements of a _list_ together as a string
without giving you errors and bad_args up the ass. If you wanna write a tuple, conver tto list first; tuple.to_list()
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

# order |> Map.from_struct() |> Map.values() |> valueList

    # Data structure, in:   {ext_orders, int_orders, masterID, versID}
    #   Extern order:       {bool_orderMatrix}
    #   Intern order:       {maskinID, boolOrderVector}
    #   Intern orders:      {maskinID_vec, boolOrderMatrix}

    # Data structure, out:  {ext_orders, int_orders, masterID, versID}
    #   Extern orders:      {bool_orderMatrix, directionParity, floorParity}
    #   Intern order:       {maskinID, boolOrderVector}
    #   Intern orders:      {maskinID_vec, maskinID_checksum, boolOrderMatrix, intVec_directionParity, intVec_floorParity}

end
