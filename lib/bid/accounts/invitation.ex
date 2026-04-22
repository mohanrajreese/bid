defmodule BidPlatform.Accounts.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "invitations" do
    field :email, :string
    field :token, :string
    field :role, :string, default: "bidder"
    field :accepted_at, :utc_datetime
    field :expired_at, :utc_datetime

    belongs_to :tenant, BidPlatform.Tenants.Tenant

    timestamps()
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:tenant_id, :email, :token, :role, :accepted_at, :expired_at])
    |> validate_required([:tenant_id, :email, :token])
    |> validate_inclusion(:role, ~w[admin bidder])
    |> unique_constraint(:token)
  end
end
