defmodule BidPlatform.Metrics do
  @moduledoc """
  Provdes global metrics across all tenants.
  Queries in this module explicitly ignore tenant scoping.
  """

  alias BidPlatform.Repo
  alias BidPlatform.Tenants.Tenant
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.Bidding.Bid
  alias BidPlatform.Accounts.User
  import Ecto.Query

  @doc "Returns high-level system stats"
  def get_system_stats do
    %{
      total_tenants: Repo.aggregate(Tenant, :count, :id),
      total_auctions: Repo.aggregate(Auction, :count, :id),
      total_bids: Repo.aggregate(Bid, :count, :id),
      total_users: Repo.aggregate(User, :count, :id)
    }
  end

  @doc "Returns a list of all tenants with summary stats"
  def list_tenant_overviews do
    Tenant
    |> join(:left, [t], u in assoc(t, :users))
    |> join(:left, [t, u], a in assoc(t, :auctions))
    |> group_by([t], t.id)
    |> select([t, u, a], %{
      id: t.id,
      name: t.name,
      subdomain: t.subdomain,
      plan: t.plan,
      is_active: t.is_active,
      user_count: count(u.id, :distinct),
      auction_count: count(a.id, :distinct),
      inserted_at: t.inserted_at
    })
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end
end
