defmodule BidPlatform.Workers.AuctionClosingWorker do
  use Oban.Worker, queue: :auctions, max_attempts: 3

  alias BidPlatform.Repo
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.Bidding.Bid
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"auction_id" => auction_id, "tenant_id" => tenant_id}}) do
    Repo.transaction(fn ->
      auction =
        Auction
        |> where([a], a.id == ^auction_id and a.tenant_id == ^tenant_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      case auction do
        nil ->
          :ok

        %Auction{status: status} when status in ["closed", "force_closed", "cancelled"] ->
          :ok

        %Auction{end_time: end_time} = auction ->
          # If the auction was extended, this job should just finish.
          # A new job will have been scheduled by ConcurrentBidHandler.
          if DateTime.compare(DateTime.utc_now(), end_time) != :lt do
            close_auction(auction)
          else
            :ok
          end
      end
    end)

    :ok
  end

  defp close_auction(auction) do
    # 1. Determine winner
    # For English: highest bid. For Reverse: lowest bid.
    winner_bid =
      Bid
      |> where([b], b.auction_id == ^auction.id)
      |> order_by_type(auction.type)
      |> limit(1)
      |> Repo.one()

    # 2. Check reserve price for English auctions
    status = determine_final_status(auction, winner_bid)

    # 3. Update auction
    updates = [
      status: status,
      updated_at: DateTime.utc_now()
    ]

    updates = if winner_bid do
      updates ++ [winner_id: winner_bid.user_id, winning_bid_id: winner_bid.id]
    else
      updates
    end

    {1, _} =
      Auction
      |> where([a], a.id == ^auction.id)
      |> Repo.update_all(set: updates)

    # 4. Broadcast
    BidPlatformWeb.Endpoint.broadcast!(
      "tenant:#{auction.tenant_id}:auction:#{auction.id}",
      "auction:closed",
      %{
        status: status,
        winner_id: if(winner_bid, do: winner_bid.user_id, else: nil),
        winning_amount: if(winner_bid, do: winner_bid.amount, else: nil)
      }
    )
  end

  defp order_by_type(query, "english"), do: order_by(query, [b], desc: b.amount, asc: b.inserted_at)
  defp order_by_type(query, "reverse"), do: order_by(query, [b], asc: b.amount, asc: b.inserted_at)

  defp determine_final_status(%Auction{bid_count: 0}, _), do: "no_bids"
  defp determine_final_status(%Auction{type: "english", reserve_price: reserve} = auction, winner_bid) when not is_nil(reserve) do
    if Decimal.compare(winner_bid.amount, reserve) != :lt do
      "closed"
    else
      "reserve_not_met"
    end
  end
  defp determine_final_status(_, _), do: "closed"
end
