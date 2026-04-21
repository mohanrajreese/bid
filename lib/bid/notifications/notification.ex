defmodule BidPlatform.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :message, :string
    field :read_at, :utc_datetime
    field :metadata, :map

    belongs_to :tenant, BidPlatform.Tenants.Tenant
    belongs_to :user, BidPlatform.Accounts.User

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:tenant_id, :user_id, :type, :title, :message, :read_at, :metadata])
    |> validate_required([:tenant_id, :user_id, :type])
  end
end
