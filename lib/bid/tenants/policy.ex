defmodule BidPlatform.Tenants.Policy do
  @moduledoc """
  Enforces tenant-level service limits and policies.
  """

  import Ecto.Query
  alias BidPlatform.Repo
  alias BidPlatform.Auctions.Auction

  @doc """
  Checks if a tenant is allowed to create more auctions this month.
  """
  def can_create_auction?(tenant) do
    limit = get_in(tenant.settings, ["max_auctions_per_month"]) || default_limit(tenant.plan)
    count = count_auctions_this_month(tenant.id)

    count < limit
  end

  defp default_limit("free"), do: 3
  defp default_limit("starter"), do: 10
  defp default_limit("professional"), do: 50
  defp default_limit("enterprise"), do: 1000

  defp count_auctions_this_month(tenant_id) do
    start_of_month = DateTime.utc_now() |> DateTime.to_date() |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    Auction
    |> where([a], a.tenant_id == ^tenant_id and a.inserted_at >= ^start_of_month)
    |> Repo.aggregate(:count, :id)
  end
end
