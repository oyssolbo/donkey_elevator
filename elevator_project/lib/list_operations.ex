defmodule ListOperations do
  @moduledoc """
  Helper module implementing multiple list-operations that are used
  in other modules
  """

  @doc """
  Function to add an element 'element' to a list 'list'

  The function first checks if the element exists in the list, and adds the
  element only if it does not already exists in the list
  """
  def add_single_element_to_list(
        new_element,
        list)
  do
    cond do
      list == []->
        [new_element]
      new_element in list->
        list
      new_element not in list->
        [list | new_element]
    end
  end

  @doc """
  Function to add a whole list to a list.

  It will only add a new element if it does not already exist in the list
  """
  def add_list_to_list(
        [first_add | rest_add],
        list)
  do
    new_list = add_single_element_to_list(first_add, list)
    add_list_to_list(rest_add, new_list)
  end

  def add_list_to_list(
        [],
        list)
  do
    list
  end



  @doc """
  Function to remove the first matching element 'element' from a list
  'list'

  Returns the new list
  """
  def remove_first_matching_element_from_list(
        element,
        list)
  do
    List.delete(list, var)
  end

  @doc """
  Removes all elements 'element' from the list 'list'

  Returns the new list
  """
  def remove_element_from_list(
        element,
        list)
  do
    original_length = length(list)
    new_list = List.delete(list, var)
    new_length = length(new_list)

    case new_length < original_length do
      :true->
        remove_element_from_list(element, new_list)

      :false->
        new_list
    end
  end

  def remove_element_from_list(
        element,
        [])
  do
    []
  end


  @doc """
  Removes an entire list from another list 'list'
  """
  def remove_list_from_list(
        [first_remove | rest_remove],
        list)
  do
    new_list = remove_element_from_list(first_remove, list)
    remove_list_from_list(rest_remove, new_list)
  end

  def remove_list_from_list(
        [],
        list)
  do
    list
  end






  @doc """
  Function to find an element in a list with a given value 'value' in
  field 'field'

  Returns a list of corresponding elements

  The function assumes that each element in list
  """
  def find_element_with_value(
        [first | rest_list]
        field,
        value)
  do
    value_first = Map.get(first, field, value)

    if value_first == value do
      [first | find_element_with_value(rest_list, field, value)]
    else
      find_element_with_value(rest_lits, field, value)
    end
  end

  def find_element_with_value(
        []
        field,
        value)
  do
    []
  end


  @doc """
  Function to set field of all of the struct/map in a list
  """
  def set_element_field(
        [element | rest_elements],
        field,
        value)
  do
    [Map.put(element, field, value) | set_element_field(rest_elements, field, value)]
  end

  def set_element_field(
        [],
        field,
        value)
  do
    []
  end

end
