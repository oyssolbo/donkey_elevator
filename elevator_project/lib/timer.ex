defmodule Timer do
  @moduledoc """
  Module for implementing timer-functions
  """

  require Time


  @doc """
  Function to start a timer

  Assuming that the given struct 'data_struct' contains a
  timer_instance which could be reset

  Returns a new instance of the given struct, with updated timer. It
  will then call the process 'process_name' if the timer has not been
  canceled within 'timeout_time', by using the name 'interrupt_atom_name'
  """
  def start_timer(
        process_name,
        data_struct,
        interrupt_atom_name,
        timeout_time)
  do
    timer = Map.get(data_struct, :timer)
    Process.cancel_timer(timer)
    new_timer = Process.send_after(process_name, interrupt_atom_name, timeout_time)
    Map.put(data_struct, :timer, new_timer)
  end


  @doc """
  Function to stop a timer - if necessary

  The function assumes that the struct 'data_struct' contains a field called
  ':timer'
  """
  def stop_timer(data_struct)
  do
    timer = Map.get(data_struct, :timer)
    Process.cancel_timer(timer)
  end


  @doc """
  Function to interrupt a process 'process_name' with the interrupt
  'interrupt_atom_name' after the time 'interrupt_time'
  """
  def interrupt_after(
        process_name,
        interrupt_atom_name,
        interrupt_time)
  do
    Process.send_after(process_name, interrupt_atom_name, interrupt_time)
  end


  @doc """
  Function for setting current UTC-time to a struct

  Sets the variable 'variable_name' in the struct 'data_struct' to
  the current UTC-time
  """
  def set_utc_time(data_struct, variable_name)
  do
    utc_time = Time.utc_now()
    Map.put(data_struct, variable_name, utc_time)
  end

end
