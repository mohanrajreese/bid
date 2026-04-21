defmodule BidPlatform.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :name, :subdomain, :slug, :plan, :is_active]}

  schema "tenants" do
    field :name, :string
    field :subdomain, :string
    field :slug, :string
    field :plan, :string, default: "free"
    field :is_active, :boolean, default: true
    field :settings, :map, default: %{}

    # Associations can be added here as other schemas are created
    # has_many :users, BidPlatform.Accounts.User
    # has_many :auctions, BidPlatform.Auctions.Auction

    timestamps()
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :subdomain, :slug, :plan, :is_active, :settings])
    |> validate_required([:name, :subdomain])
    |> validate_format(:subdomain, ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/, message: "must be lowercase alphanumeric with optional hyphens")
    |> validate_length(:subdomain, min: 3, max: 63)
    |> unique_constraint(:subdomain)
    |> validate_exclusion(:subdomain, ~w[www api admin app dashboard mail ftp], message: "is reserved")
  end
end
