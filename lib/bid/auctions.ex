  @moduledoc """
  The Auctions context provides functionality for managing auction lifecycles,
  including creation, status updates, and anti-sniping extensions.
  """

  import Ecto.Query, warn: false
  alias BidPlatform.Repo
  alias BidPlatform.Auctions.Auction

  @doc """
  Returns the list of auctions for a specific tenant.
  """
  def list_auctions(tenant_id) do
    Auction
    |> where([a], a.tenant_id == ^tenant_id)
    |> Repo.all()
  end

  @doc """
  Gets a single auction within a tenant.
  """
  def get_auction(tenant_id, id) do
    Auction
    |> where([a], a.id == ^id and a.tenant_id == ^tenant_id)
    |> Repo.one()
  end

  @doc """
  Creates an auction.
  """
  def create_auction(attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, auction} <- %Auction{} |> Auction.changeset(attrs) |> Repo.insert() do
        # Schedule closing job
        schedule_closing_job(auction)
        auction
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp schedule_closing_job(auction) do
    %{auction_id: auction.id, tenant_id: auction.tenant_id}
    |> BidPlatform.Workers.AuctionClosingWorker.new(scheduled_at: auction.end_time)
    |> Oban.insert!()
  end

  @doc """
  Updates an auction.
  """
  def update_auction(%Auction{} = auction, attrs) do
    auction
    |> Auction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an auction.
  """
  def delete_auction(%Auction{} = auction) do
    Repo.delete(auction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking auction changes.
  """
  def change_auction(%Auction{} = auction, attrs \\ %{}) do
    Auction.changeset(auction, attrs)
  end
end
