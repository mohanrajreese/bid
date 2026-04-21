defmodule BidPlatform.AuditLogs do
  @moduledoc """
  The AuditLogs context.
  """

  import Ecto.Query, warn: false
  alias BidPlatform.Repo
  alias BidPlatform.AuditLogs.AuditLog

  @doc """
  Records a new audit log entry.
  """
  def log(attrs) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists audit logs for a tenant.
  """
  def list_logs(tenant_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    AuditLog
    |> where([l], l.tenant_id == ^tenant_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
  end
end
