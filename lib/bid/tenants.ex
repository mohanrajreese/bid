defmodule BidPlatform.Tenants do
  @moduledoc """
  The Tenants context.
  """

  import Ecto.Query, warn: false
  alias BidPlatform.Repo
  alias BidPlatform.Tenants.Tenant

  @doc """
  Returns the list of tenants.
  """
  def list_tenants do
    Repo.all(Tenant)
  end

  @doc """
  Gets a single tenant.
  Raises `Ecto.NoResultsError` if the Tenant does not exist.
  """
  def get_tenant!(id), do: Repo.get!(Tenant, id)

  @doc """
  Creates a tenant.
  """
  def create_tenant(attrs \\ %{}) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tenant.
  """
  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  Deletes a tenant.
  """
  def delete_tenant(%Tenant{} = tenant) do
    Repo.delete(tenant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tenant changes.
  """
  def change_tenant(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.changeset(tenant, attrs)
  end
end
