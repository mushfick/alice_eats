defmodule Alice.Eats.Group do
  @enforce_keys [:name]
  defstruct name: "", members: [], restaurants: []
  alias Alice.Eats.Group

  def join(%Group{members: members}=group, user_id) do
    if user_id in members do
      {:error, :already_member}
    else
      {:ok, %{group | members: [user_id | members]}}
    end
  end

  def leave(%Group{members: members}=group, user_id) do
    {:ok, %{group | members: List.delete(members, user_id)}}
  end

  def add_restaurant(%Group{restaurants: restaurants}=group, restaurant) do
    if restaurant in restaurants do
      {:error, :already_exists, restaurant, group.name}
    else
      {:ok, %{group | restaurants: [restaurant | restaurants]}}
    end
  end

  def remove_restaurant(%Group{restaurants: restaurants}=group, restaurant) do
    {:ok, %{group | restaurants: List.delete(restaurants, restaurant)}}
  end
end
