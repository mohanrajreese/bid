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
  Gets a single user by ID only. Use with caution as it bypasses tenant isolation.
  Only for internal authentication purposes.
  """
  def get_user!(id), do: Repo.get!(User, id)

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
  Authenticates a user by email and password within a tenant.
  """
  def authenticate_user(tenant_id, email, password) do
    user = get_user_by_email(tenant_id, email)

    cond do
      user && user.is_active && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :unauthorized}

      true ->
        # Prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
end
