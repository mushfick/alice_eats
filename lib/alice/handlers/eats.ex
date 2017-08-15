require IEx;

defmodule Alice.Handlers.Eats do
  @moduledoc """
  This is an Alice handler to help you decide what to eat.
  """
  use Alice.Router
  alias Alice.{Conn,Eats.Group}
  @nogroup_error_message "You are not a member of any group. Use the join command to join a group."
  @norestaurant_error_message "You do not have any restraunts added in this group. Use the add command to add a restaurant first."

  command ~r/eats members/i,                  :list_members
  command ~r/eats list groups/i,              :list_groups
  command ~r/eats join (.+)/i,                :join_group
  command ~r/eats leave/i,                    :leave_group
  command ~r/eats add (.+)/i,                 :add_restaurant
  command ~r/eats remove (.+)/i,              :remove_restaurant
  command ~r/eats list\z/i,                   :list_restaurants
  command ~r/where should I eat\??/i,         :choose
  command ~r/what'?s for (lunch|dinner)\??/i, :choose
  route   ~r/I'?m(.*) h(u|a)ngry/i,           :choose_opt
  route   ~r/I (want|need)(.*) (grub|food)/i, :choose_opt

  @doc "`eats members` - list all members in all groups"
  def list_members(conn) do
    conn
    |> get_groups()
    |> Map.values()
    |> Enum.map(fn
      %Group{name: name, members: []} -> "*#{name}*:\n_No members._"
      %Group{name: name, members: members} ->
        "*#{name}*:\n#{members |> Enum.map(&member_name(conn, &1)) |> Enum.join("\n")}"
    end)
    |> Enum.join("\n")
    |> reply(conn)
  end

  @doc "`eats list groups` - list all groups"
  def list_groups(conn) do
    conn
    |> get_groups()
    |> Map.keys()
    |> format_group_list
    |> reply(conn)
  end

  @doc "`eats join <group>` - join a group (and create it if it doesn't exist)"
  def join_group(conn) do
    with group_name         <- Conn.last_capture(conn),
         groups             <- get_groups(conn),
         {:error, :nogroup} <- get_current_group(Map.values(groups), conn),
         group              <- get_group(groups, group_name),
         {:ok, group}       <- Group.join(group, user_id(conn)),
         groups             <- Map.put(groups, group_name, group) do
      put_state(conn, :eats_groups, groups)
      "Added #{Conn.at_reply_user(conn)} to the group *#{group_name}*."
    else
      {:ok, %Group{name: name}} -> "You are already a member of *#{name}*."
    end
    |> reply(conn)
  end

  @doc "`eats leave` - leave your current group"
  def leave_group(conn) do
    with groups       <- get_groups(conn),
         {:ok, group} <- get_current_group(Map.values(groups), conn),
         {:ok, group} <- Group.leave(group, user_id(conn)),
         groups       <- Map.put(groups, group.name, group) do
      put_state(conn, :eats_groups, groups)
      "Removed #{Conn.at_reply_user(conn)} from the group *#{group.name}*."
    else
      {:error, :nogroup} -> @nogroup_error_message
    end
    |> reply(conn)
  end

  @doc "`eats add <restaurant>` - add a new restaurant to your group"
  def add_restaurant(conn) do
    with restaurant   <- Conn.last_capture(conn),
         groups       <- get_groups(conn),
         {:ok, group} <- get_current_group(Map.values(groups), conn),
         {:ok, group} <- Group.add_restaurant(group, restaurant),
         groups       <- %{groups | group.name => group} do
      put_state(conn, :eats_groups, groups)
      "Added #{restaurant} to *#{group.name}*."
    else
      {:error, :already_exists, restaurant, group_name} ->
        "#{restaurant} is already in *#{group_name}*."
      {:error, :nogroup} -> @nogroup_error_message
    end
    |> reply(conn)
  end

  @doc "`eats remove <restaurant>` - remove a restaurant from your group"
  def remove_restaurant(conn) do
    with restaurant   <- Conn.last_capture(conn),
         groups       <- get_groups(conn),
         {:ok, group} <- get_current_group(Map.values(groups), conn),
         {:ok, group} <- Group.remove_restaurant(group, restaurant),
         groups       <- %{groups | group.name => group} do
      put_state(conn, :eats_groups, groups)
      "Removed #{restaurant} from *#{group.name}*."
    else
      {:error, :nogroup} -> @nogroup_error_message
    end
    |> reply(conn)
  end

  @doc "`eats list` - list all restaurants in your group"
  def list_restaurants(conn) do
    with groups <- Map.values(get_groups(conn)),
         {:ok, group} <- get_current_group(groups, conn),
         %Group{name: name, restaurants: restaurants} <- group do
      "Restaurants in *#{name}*:\n#{Enum.join(restaurants, "\n")}"
    else
      {:error, :nogroup} -> @nogroup_error_message
    end
    |> reply(conn)
  end

  @doc """
  `where should I eat?`
  `what's for lunch?`
    - have Alice suggest a place to eat
  """
  def choose(conn) do
    with groups <- Map.values(get_groups(conn)),
         {:ok, group} <- get_current_group(groups, conn),
         %Group{restaurants: restaurants} <- group do
      "You should get some eats at *#{Enum.random(restaurants)}*!"
    else
      {:error, :nogroup} -> @nogroup_error_message
    end
    |> reply(conn)
  end

  @doc "`I'm hungry` - have Alice suggest a place to eat (ignored if not in a group)"
  def choose_opt(conn) do
    with groups <- Map.values(get_groups(conn)),
         {:ok, group} <- get_current_group(groups, conn),
         %Group{restaurants: restaurants} <- group do
      reply(conn, "You should get some eats at *#{Enum.random(restaurants)}*!")
    else
      _ -> conn
    end
  end

  defp member_name(%Conn{slack: %{users: users}}, user_id) do
    user = users[user_id]
    case user.real_name do
      "" -> user.name
      name -> name
    end
  end

  defp get_group(groups, group_name) do
    case groups do
      %{^group_name => group} -> group
      _ -> %Group{name: group_name}
    end
  end

  defp get_current_group(groups, conn) do
    Enum.find(groups, :nogroup, fn(group) ->
      Enum.member?(group.members, user_id(conn))
    end)
    |> case do
      :nogroup -> {:error, :nogroup}
      group    -> {:ok, group}
    end
  end

  defp format_group_list([]) do
    "No groups. You can add a group with the join command."
  end
  defp format_group_list(group_names) do
    IEx.pry
    "Here are the current groups:\n*#{group_names |> Enum.with_index |> Enum.each(fn({group_name, id}) -> "#{index + 1}". "#{group_name}*\n*" end)}*"
  end

  defp user_id(%Conn{message: %{user: id}}), do: id

  defp get_groups(conn) do
    for {name, group} <- get_state(conn, :eats_groups, %{}), into: %{} do
      {name, struct(Group, atomify_keys(group))}
    end
  end

  defp atomify_keys(map) do
    for {key, val} <- map, into: %{} do
      {String.to_existing_atom(key), val}
    end
  end
end
