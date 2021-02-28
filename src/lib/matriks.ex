defmodule Matriks do
    
    @moduledoc """
  Helpers for working with multidimensional lists, also called matrices.
  Stolen from https://blog.danielberkompas.com/2016/04/23/multidimensional-arrays-in-elixir/
  """

  @doc """
  Converts a multidimensional list into a zero-indexed map.
  
  ## Example
  
      iex> list = [["x", "o", "x"]]
      ...> Matriks.from_list(list)
      %{0 => %{0 => "x", 1 => "o", 2 => "x"}}
  """
  def from_list(list) when is_list(list) do
    do_from_list(list)
  end

  defp do_from_list(list, map \\ %{}, index \\ 0)
  defp do_from_list([], map, _index), do: map
  defp do_from_list([h|t], map, index) do
    map = Map.put(map, index, do_from_list(h))
    do_from_list(t, map, index + 1)
  end
  defp do_from_list(other, _, _), do: other

  @doc """
  Converts a zero-indexed map into a multidimensional list.
  
  ## Example
  
      iex> matrix = %{0 => %{0 => "x", 1 => "o", 2 => "x"}}
      ...> Matriks.to_list(matrix)
      [["x", "o", "x"]]
  """
  def to_list(matrix) when is_map(matrix) do
    do_to_list(matrix)
  end

  defp do_to_list(matrix) when is_map(matrix) do
    for {_index, value} <- matrix,
        into: [],
        do: do_to_list(value)
  end
  defp do_to_list(other), do: other

  # Utility functions for elevator-related modules
  def falseOrderMatrix do
    from_list([[false, false, false, false], [false, false, false, false], [false, false, false,false]])
  end
  def rndOrderMatrix do
    from_list([[Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])], 
               [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])], 
               [Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true]), Enum.random([false,true])]])
  end
  def orderMatrixOR(mn, mo) do
      [[mn[0][0] or mo[0][0], mn[0][1] or mo[0][1], mn[0][2] or mo[0][2], mn[0][3] or mo[0][3]],
       [mn[1][0] or mo[1][0], mn[1][1] or mo[1][1], mn[1][2] or mo[1][2], mn[1][3] or mo[1][3]],
       [mn[2][0] or mo[2][0], mn[2][1] or mo[2][1], mn[2][2] or mo[2][2], mn[2][3] or mo[2][3]]]
  end
end


