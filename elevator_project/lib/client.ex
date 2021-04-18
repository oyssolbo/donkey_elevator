defmodule Client do
  @moduledoc """
  Module wrapping the ID for each client that exist between between
  two modules. This module is implemented to standardize the identification
  of client between the modules

  But yeah, this does not need to be it's own module.
  """

  require Timer
  require Logger

  defstruct [
    client_id:        :nil, # IP-address to differentiate
    client_data:      :nil,
    client_timer:     :nil, # Last time a message was received. Useful for throwing a timeout
    last_message_id:  0
  ]

## Add client(s) ##
  @doc """
  Function to add client(s) to a list of clients
  """
  def add_clients(
        %Client{} = new_client,
        client_list)
  when client_list |> is_list()
  do
    case client_list do
      []->
        [new_client]
      _->
        old_client_list =
          Map.get(new_client, :client_id) |>
          extract_client(client_list)

        updated_client_list =
          case old_client_list do
            []->
              client_list
            _->
              remove_clients(old_client_list, client_list)
          end

        updated_client_list ++ [new_client]
    end
  end

  def add_clients(
        [client | rest_clients],
        client_list)
  when client_list |> is_list()
  do
    temp_client_list = add_clients(client, client_list)
    add_clients(rest_clients, temp_client_list)
  end

  def add_clients(
        [],
        client_list)
  when client_list |> is_list()
  do
    client_list
  end


## Remove client(s) ##
  @doc """
  Function that removes a single or a list of clients from another list of clients

  The function searches through the entire list, such that if a duplicated
  client has occured, all duplicates are removed
  """
  def remove_clients(
        %Client{} = client,
        client_list)
  when client_list |> is_list()
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
  Function to remove a list of clients from another list of clients

  It is assumed that there is only one copy of each order in the list
  """
  def remove_clients(
        [],
        client_list)
  when client_list |> is_list()
  do
    client_list
  end

  def remove_clients(
        clients,
        client_list)
  when clients |> is_list() and client_list |> is_list()
  do
    Enum.map(clients, fn client -> remove_clients(client, client_list) end) |>
      List.flatten()
  end


## Extract client(s) ##
  @doc """
  Function that finds a client with client_id: 'id' in a list of clients

  The function returns a client with correct client_id, or an empty list
  if the client is not found
  """
  def extract_client(
        client_id,
        client_list)
  when client_list |> is_list()
  do
    Enum.filter(client_list, fn x -> x.client_id == client_id end)
  end

## Modify client ##
  @doc """
  Function that modifies a field in either a single client or a list of clients. The
  field 'field' is set to value 'value'.

  The list if clients is only modified if the entire list is made of % Clients
  """
  def modify_client_field(
        %Client{} = client,
        field,
        value)
  do
    Map.put(client, field, value)
  end

  def modify_client_field(
        clients,
        field,
        value)
  when clients |> is_list()
  do
    Enum.map(clients, fn client -> Map.put(client, field, value) end)
  end


  @doc """
  Function to cancel the timers in a list of clients

  The function assumes that the parameter 'clients' is a list
  """
  def cancel_all_client_timers(clients)
  when clients |> is_list()
  do
    Enum.map(clients, fn client -> Timer.stop_timer(client, :client_timer) end)
  end

end
