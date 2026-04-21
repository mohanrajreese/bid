defmodule BidPlatform.Repo.TenantPreparer do
  @moduledoc """
  Sets the PostgreSQL session variable for Row-Level Security
  on every database connection checkout.

  This provides database-level tenant isolation as a backup
  to application-level TenantScope enforcement.
  """

  @doc """
  Call this at the start of every request to set the tenant context
  on the current database connection.
  """
  def set_tenant(tenant_id) do
    Ecto.Adapters.SQL.query!(
      BidPlatform.Repo,
      "SET app.current_tenant_id = $1",
      [tenant_id]
    )
  end
end
