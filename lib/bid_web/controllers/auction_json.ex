defmodule BidPlatformWeb.AuctionJSON do
  alias BidPlatform.Auctions.Auction

  def index(%{auctions: auctions}) do
    %{data: for(auction <- auctions, do: data(auction))}
  end

  def show(%{auction: auction}) do
    %{data: data(auction)}
  end

  defp data(%Auction{} = auction) do
    %{
      id: auction.id,
      title: auction.title,
      description: auction.description,
      type: auction.type,
      start_price: auction.start_price,
      current_price: auction.current_price,
      min_increment: auction.min_increment,
      reserve_price: auction.reserve_price,
      start_time: auction.start_time,
      end_time: auction.end_time,
      status: auction.status,
      bid_count: auction.bid_count,
      tenant_id: auction.tenant_id,
      created_by: auction.created_by
    }
  end
end
