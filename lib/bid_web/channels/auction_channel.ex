defmodule BidPlatformWeb.AuctionChannel do
  use BidPlatformWeb, :channel

  alias BidPlatform.Auctions
  alias BidPlatform.TenantScope

  @doc """
  Topic format: tenant:{tenant_id}:auction:{auction_id}
  Example: tenant:abc123:auction:xyz789
  """
  def join("tenant:" <> tenant_and_auction, _payload, socket) do
    case String.split(tenant_and_auction, ":auction:") do
      [topic_tenant_id, auction_id] ->
        # Enforce tenant isolation
        if socket.assigns.tenant_id == topic_tenant_id do
          # Optional: Verify auction exists and belongs to this tenant
          case Auctions.get_auction(socket.assigns.tenant_id, auction_id) do
            nil ->
              {:error, %{reason: "auction_not_found"}}

            auction ->
              # Success: Send current auction state to the client
              {:ok, render_auction_state(auction), assign(socket, :auction_id, auction_id)}
          end
        else
          {:error, %{reason: "unauthorized_tenant_access"}}
        end

      _ ->
        {:error, %{reason: "invalid_topic_format"}}
    end
  end

  defp render_auction_state(auction) do
    %{
      id: auction.id,
      status: auction.status,
      current_price: auction.current_price,
      bid_count: auction.bid_count,
      end_time: auction.end_time
    }
  end
end
