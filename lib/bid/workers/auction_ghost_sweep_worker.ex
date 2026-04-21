defmodule BidPlatform.Workers.AuctionGhostSweepWorker do
  @moduledoc """
  Finds active auctions that should have closed but haven't.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  alias BidPlatform.Repo
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.Workers.AuctionClosingWorker
  import Ecto.Query

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    # Find auctions that are past their end_time but still in active/scheduled status
    Auction
    |> where([a], a.status in ["active", "scheduled"] and a.end_time <= ^now)
    |> Repo.all()
    |> Enum.each(fn auction ->
      # Enqueue a closing job for each found auction
      %{auction_id: auction.id, tenant_id: auction.tenant_id}
      |> AuctionClosingWorker.new()
      |> Oban.insert()
    end)

    :ok
  end
end
