defmodule BidPlatform.Bidding.ConcurrentBidHandler do
  @moduledoc """
  Handles concurrency-safe bid placement using PostgreSQL row-level locks.
  """

  alias BidPlatform.Repo
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.Bidding.Bid
  import Ecto.Query

  @lock_timeout_ms 5_000

  def place_bid(tenant_id, auction_id, user_id, amount) do
    Repo.transaction(
      fn ->
        # 1. Acquire exclusive lock on the auction row
        auction =
          Auction
          |> where([a], a.id == ^auction_id and a.tenant_id == ^tenant_id)
          |> lock("FOR UPDATE")
          |> Repo.one()

        case auction do
          nil ->
            Repo.rollback(:auction_not_found)

          %Auction{status: status} when status != "active" ->
            Repo.rollback({:auction_not_active, status})

          %Auction{} = auction ->
            # 2. Validate bid against the locked state
            case validate_bid_amount(auction, user_id, amount) do
              :ok ->
                # 3. Execute bid insertion and auction update
                execute_bid(auction, tenant_id, user_id, amount)

              {:error, reason} ->
                Repo.rollback(reason)
            end
        end
      end,
      timeout: @lock_timeout_ms + 1_000
    )
  end

  defp validate_bid_amount(%Auction{type: "english"} = auction, user_id, amount) do
    min_required = Decimal.add(auction.current_price, auction.min_increment)

    cond do
      auction.created_by == user_id ->
        {:error, :self_bidding_not_allowed}

      Decimal.compare(amount, min_required) == :lt ->
        {:error, {:insufficient_bid, min_required}}

      true ->
        :ok
    end
  end

  defp validate_bid_amount(%Auction{type: "reverse"} = auction, user_id, amount) do
    max_allowed = Decimal.sub(auction.current_price, auction.min_increment)

    cond do
      auction.created_by == user_id ->
        {:error, :self_bidding_not_allowed}

      Decimal.compare(amount, max_allowed) == :gt ->
        {:error, {:bid_too_high, max_allowed}}

      Decimal.compare(amount, Decimal.new(0)) != :gt ->
        {:error, :bid_must_be_positive}

      true ->
        :ok
    end
  end

  defp execute_bid(auction, tenant_id, user_id, amount) do
    # Insert bid
    {:ok, bid} =
      %Bid{}
      |> Bid.changeset(%{
        tenant_id: tenant_id,
        auction_id: auction.id,
        user_id: user_id,
        amount: amount,
        status: "valid"
      })
      |> Repo.insert()

    # Update auction
    {1, _} =
      Auction
      |> where([a], a.id == ^auction.id)
      |> Repo.update_all(
        set: [current_price: amount, updated_at: DateTime.utc_now()],
        inc: [bid_count: 1]
      )

    # Broadcast bid
    BidPlatformWeb.Endpoint.broadcast!(
      "tenant:#{tenant_id}:auction:#{auction.id}",
      "bid:new",
      %{
        bid_id: bid.id,
        amount: bid.amount,
        bidder_id: user_id,
        current_price: amount,
        bid_count: auction.bid_count + 1,
        end_time: auction.end_time
      }
    )

    %{bid: bid, auction: %{auction | current_price: amount, bid_count: auction.bid_count + 1}}
  end
end
