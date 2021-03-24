defmodule ConnectionID do
  @moduledoc """
  Module wrapping the ID for each connection that exist between between
  two modules. This module is implemented to standardize the identification
  of connection between the modules

  But yeah, this does not need to be it's own module.
  """

  require Time

  defstruct [:connection_start_time, :message_sequence_number]


  @doc """
  Function that checks if two messages are sent during the same connection.


  Must think more about this function
  

  mess_ref    Message that works as a reference
  mess_check  Message to be checked

  Returns               If
  :true                 connection_start_time equal
  :false                connection_start_time not equal
  """
  def check_connection_start_time(mess_ref, mess_check)
  do
    time_ref = Map.get(mess_ref, :connection_start_time)
    time_check = Map.get(mess_check, :connection_start_time)

    compare_time = Time.compare(time_ref, time_check)

    if compare_time in [:lt, :gt] do
      :false
    else
      :true
    end
  end


  @doc """
  Function that checks if two messages are in the same sequence

  mess_ref    Message that works as a reference
  mess_check  Message to be checked

  Returns               If
  :true                 connection_start_time equal
  :false                connection_start_time not equal
  """
  def check_connection_id(mess_ref, mess_check)
  do
    time_ref = Map.get(mess_ref, :connection_start_time)
    time_check = Map.get(mess_check, :connection_start_time)

    compare_time = Time.compare(time_ref, time_check)

    if compare_time in [:lt, :gt] do
      :false
    else
      :true
    end
  end



end
