defmodule BidPlatform.Bidding.Bid do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :amount, :status, :metadata, :inserted_at, :tenant_id, :auction_id, :user_id]}

  schema "bids" do
    field :amount, :decimal
    field :status, :string, default: "valid"
    field :metadata, :map, default: %{}

    belongs_to :tenant, BidPlatform.Tenants.Tenant, type: :binary_id
    belongs_to :auction, BidPlatform.Auctions.Auction, type: :binary_id
    belongs_to :user, BidPlatform.Accounts.User, type: :binary_id

    timestamps()
  end

  def changeset(bid, attrs) do
    bid
    |> cast(attrs, [:amount, :status, :metadata, :tenant_id, :auction_id, :user_id])
    |> validate_required([:amount, :tenant_id, :auction_id, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:auction_id)
    |> foreign_key_constraint(:user_id)
  end
end
