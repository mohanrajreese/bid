defmodule BidPlatform.Bidding.ProxyBid do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "proxy_bids" do
    field :max_amount, :decimal
    field :is_active, :boolean, default: true

    belongs_to :tenant, BidPlatform.Tenants.Tenant
    belongs_to :auction, BidPlatform.Auctions.Auction
    belongs_to :user, BidPlatform.Accounts.User

    timestamps()
  end

  def changeset(proxy_bid, attrs) do
    proxy_bid
    |> cast(attrs, [:tenant_id, :auction_id, :user_id, :max_amount, :is_active])
    |> validate_required([:tenant_id, :auction_id, :user_id, :max_amount])
    |> validate_positive_amount()
  end

  defp validate_positive_amount(changeset) do
    validate_change(changeset, :max_amount, fn :max_amount, amount ->
      if Decimal.compare(amount, 0) == :gt do
        []
      else
        [max_amount: "must be greater than 0"]
      end
    end)
  end
end
