defmodule Client do
  @moduledoc """
  Module wrapping the ID for each client that exist between between
  two modules. This module is implemented to standardize the identification
  of client between the modules

  But yeah, this does not need to be it's own module.
  """

  require Timer

  defstruct [
    client_id:          :nil,                 # IP-address to differentiate
    client_data:        :nil,
    last_message_time:  Timer.get_utc_time(), # Last time a message was received. Useful for throwing a timeout
    last_message_id:    0
  ]


  @doc """
  Function that finds a client with client_id: 'id' in a list of clients

  The function returns a client with correct client_id, or an empty list
  if the client is not found
  """
  def find_client(
        id,
        [check_client | rest_client])
  do
    check_client_id = Map.get(check_client, :client_id)

    case check_client_id == id do
      :true->
        check_client
      :false->
        find_client(id, rest_client)
    end
  end

  def find_client(
        id,
        [])
  do
    []
  end


  @doc """
  Function that removes a single client from a list of clients
  """
  def remove_clients(
        client,
        client_list)
  when client |> is_struct()
  do
    original_length = length(client_list)
    new_list = List.delete(client_list, client)
    new_length = length(new_list)

    case new_length < original_length do
      :true->
        remove_clients(client, new_list)
      :false->
        new_list
    end
  end

  @doc """
  Function to remove a list of clientss from another list of clients

  It is assumed that there is only one copy of each client in the list
  """
  def remove_clients(
        [client | rest_clients],
        client_list)
  do
    new_list = remove_clients(client, client_list)
    remove_clients(rest_clients, new_list)
  end

  def remove_clients(
        [],
        client_list)
  do
    client_list
  end


  @doc """
  Function that adds a client to a list of client

  The function checks if a client with the corresponding client_id already
  exists in the list. If false, the client is added to the list.
  """
  def add_client(
        client,
        client_list)
  do
    client_id_in_list =
      Map.get(client, :client_id) |>
      find_client(client_list)

    if client_id_in_list != [] do
      client_list
    else
      [client_list | client]
    end
  end


  @doc """
  Function to assign a field 'field' in the client-struct to a value 'value'

  This function iterates over all clients in a list, and returns the updated
  client-list
  """
  # def set_all_client_field(
  #       client_list,
  #       field,
  #       value)
  # do
  #   updated_client = Map.put(client, field, value)
  #   [updated_client | set_client_field(rest_clients, field, value)]
  # end

  # def set_all_client_field(
  #       [],
  #       field,
  #       value)
  # do
  #   []
  # end


  @doc """
  Function to cancel the timers in a list of clients
  """
  def cancel_all_client_timers([client | rest_clients])
  do
    Timer.stop_timer(client, :last_message_time)
    [client | cancel_all_client_timers(rest_clients)]
  end

  def cancel_all_client_timers([])
  do
    []
  end

end
