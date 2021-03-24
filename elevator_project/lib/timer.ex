defmodule Timer do
  @moduledoc """
  Module for implementing timer for use in the different
  modules
  """

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
  Function to interrupt
  """
  def interrupt_after(
        process_name,
        interrupt_atom_name,
        interrupt_time)
  do
    Process.send_after(process_name, interrupt_atom_name, interrupt_time)
  end

end
