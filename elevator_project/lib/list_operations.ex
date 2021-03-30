defmodule ListOperations do
  @moduledoc """
  Helper module implementing multiple list-operations that are used
  in other modules
  """

  require List

  @doc """
  Function to add an element 'element' to a list 'list'
  """
  def add_element_to_list(
        element,
        list)
  do
    [list | element]
  end

  @doc """
  Function to remove the first matching element 'var' from a list
  'list'

  Returns the new list
  """
  def remove_first_var_from_list(
        var,
        list)
  do
    List.delete(list, var)
  end

  @doc """
  Removes all elements 'var' from the list 'list'

  Returns the new list
  """
  def remove_all_vars_from_list(
        var,
        list)
  do
    new_list = List.delete(list, var)
    remove_all_vars_from_list(var, new_list)
  end

  def remove_all_vars_from_list(
        var,
        list)
  do
    list
  end


  @doc """
  Function to find an element in a list

  Returns the element if found, or :nil if not found
  """
  def find_element_in_list(
        element,
        list)
  do
    
  end




end
