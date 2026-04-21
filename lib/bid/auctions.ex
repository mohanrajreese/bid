defmodule BidPlatform.Auctions do
  @moduledoc """
  The Auctions context.
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
    %Auction{}
    |> Auction.changeset(attrs)
    |> Repo.insert()
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
