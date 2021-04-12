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
  when is_list(client_list)
  do
    old_client = extract_client(new_client.client_id, client_list)
    IO.inspect(old_client)

    case client_list do
      []->
        [new_client]
      _->
        case old_client do
          []->
            client_list ++ [new_client]
          _->
            temp_client_list = remove_clients(old_client, client_list)
            temp_client_list ++ [new_client]
        end
    end
  end

  def add_clients(
        [client | rest_clients],
        client_list)
  when is_list(client_list)
  do
    temp_client_list = add_clients(client, client_list)
    add_clients(rest_clients, temp_client_list)
  end

  def add_clients(
        [],
        client_list)
  when is_list(client_list)
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
  when is_list(client_list)
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
  when is_list(client_list)
  do
    client_list
  end

  def remove_clients(
        clients,
        client_list)
  when is_list(clients) and is_list(client_list)
  do
    if is_client_list(client_list) and is_client_list(clients) do
      Enum.map(clients, fn client -> remove_clients(client, client_list) end)
    else
      Logger.info("Not a client-list")
      []
    end
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
    if is_client_list(client_list) do
      Enum.filter(client_list, fn x -> x.client_id == client_id end)
    else
      Logger.info("Not a client-list")
      []
    end
  end


## Check client(s) ##
  @doc """
  Function to check whether list contains only clients. Returns :false if
  at least one element is not of struct %Client{}
  """
  defp is_client_list(list)
  when is_list(list)
  do
    Enum.all?(list, fn
      %Client{} -> :true
      _ -> :false
    end)
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
    if is_client_list(clients) do
      Enum.map(clients, fn client -> Map.put(client, field, value) end)
    else
      Logger.info("Not a client-list")
      clients
    end
  end


  @doc """
  Function to cancel the timers in a list of clients

  The function assumes that the parameter 'clients' is a list
  """
  def cancel_all_client_timers(clients)
  when is_list(clients)
  do
    if is_client_list(clients) do
      Enum.map(clients, fn client -> Timer.stop_timer(client, :last_message_time) end)
    else
      Logger.info("Not a client-list")
      clients
    end
  end

end
