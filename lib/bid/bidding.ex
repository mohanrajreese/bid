defmodule BidPlatform.Bidding do
  @moduledoc """
  The Bidding context.
  """

  import Ecto.Query, warn: false
  alias BidPlatform.Repo
  alias BidPlatform.Bidding.Bid
  alias BidPlatform.Bidding.ConcurrentBidHandler

  @doc """
  Places a bid safely using pessimistic locking.
  """
  def place_bid(tenant_id, auction_id, user_id, amount) do
    ConcurrentBidHandler.place_bid(tenant_id, auction_id, user_id, amount)
  end

  @doc """
  Returns the list of bids for an auction.
  """
  def list_bids(tenant_id, auction_id) do
    Bid
    |> where([b], b.tenant_id == ^tenant_id and b.auction_id == ^auction_id)
    |> order_by([b], desc: b.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single bid.
  """
  def get_bid(tenant_id, id) do
    Bid
    |> where([b], b.id == ^id and b.tenant_id == ^tenant_id)
    |> Repo.one()
  end

  @doc """
  Creates a bid.
  """
  def create_bid(attrs \\ %{}) do
    %Bid{}
    |> Bid.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bid changes.
  """
  def change_bid(%Bid{} = bid, attrs \\ %{}) do
    Bid.changeset(bid, attrs)
  end
end
