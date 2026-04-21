defmodule BidPlatform.AuditLogs.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :changes, :map
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :tenant, BidPlatform.Tenants.Tenant
    belongs_to :user, BidPlatform.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:tenant_id, :user_id, :action, :resource_type, :resource_id, :changes, :ip_address, :user_agent])
    |> validate_required([:tenant_id, :action, :resource_type])
  end
end
