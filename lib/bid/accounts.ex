defmodule BidPlatform.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias BidPlatform.Repo
  alias BidPlatform.Accounts.User

  @doc """
  Returns the list of users for a specific tenant.
  """
  def list_users(tenant_id) do
    User
    |> where([u], u.tenant_id == ^tenant_id)
    |> Repo.all()
  end

  @doc """
  Gets a single user within a tenant.
  """
  def get_user(tenant_id, id) do
    User
    |> where([u], u.id == ^id and u.tenant_id == ^tenant_id)
    |> Repo.one()
  end

  @doc """
  Gets a single user by email within a tenant.
  Useful for authentication.
  """
  def get_user_by_email(tenant_id, email) do
    User
    |> where([u], u.email == ^email and u.tenant_id == ^tenant_id)
    |> Repo.one()
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
end
