defmodule BidPlatform.AuditLogs do
  @moduledoc """
  The AuditLogs context records all sensitive mutations for compliance and security auditing.

  Logs include metadata such as IP address and user agents to track the origin of actions.
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

  @doc """
  Lists audit logs globally (Super Admin only).
  """
  def list_all_logs(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    AuditLog
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload([:user, :tenant])
    |> Repo.all()
  end
end
