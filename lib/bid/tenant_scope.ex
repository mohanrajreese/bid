defmodule BidPlatform.TenantScope do
  import Ecto.Query

  @doc """
  Scopes any queryable to a specific tenant.
  """
  def scope(queryable, tenant_id) do
    from q in queryable, where: q.tenant_id == ^tenant_id
  end

  @doc """
  Scopes and fetches a single record. Returns nil if not found or if the record belongs to a different tenant.
  """
  def get(queryable, tenant_id, id) do
    queryable
    |> scope(tenant_id)
    |> where([q], q.id == ^id)
    |> BidPlatform.Repo.one()
  end

  @doc """
  Scopes and fetches a single record. Raises if not found.
  This is the safe equivalent of Repo.get! — it ensures tenant isolation.
  """
  def get!(queryable, tenant_id, id) do
    case get(queryable, tenant_id, id) do
      nil -> raise Ecto.NoResultsError, queryable: queryable
      record -> record
    end
  end
end
