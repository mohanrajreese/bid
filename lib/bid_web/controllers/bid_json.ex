defmodule BidPlatformWeb.BidJSON do
  alias BidPlatform.Bidding.Bid

  def index(%{bids: bids}) do
    %{data: for(bid <- bids, do: data(bid))}
  end

  def show(%{bid: bid}) do
    %{data: data(bid)}
  end

  defp data(%Bid{} = bid) do
    %{
      id: bid.id,
      amount: bid.amount,
      status: bid.status,
      inserted_at: bid.inserted_at,
      auction_id: bid.auction_id,
      user_id: bid.user_id
    }
  end
end
