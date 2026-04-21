defmodule BidPlatformWeb.AuctionController do
  use BidPlatformWeb, :controller

  alias BidPlatform.Auctions
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.TenantScope

  # Allow bidders to view; only admins can create/update/delete
  plug BidPlatformWeb.Plugs.Authorize, [roles: ["admin"]] when action in [:create, :update, :delete]
  plug BidPlatformWeb.Plugs.Authorize, [roles: ["admin", "bidder"]] when action in [:index, :show]

  def index(conn, _params) do
    tenant_id = conn.assigns.tenant_id
    # We use a custom query to ensure isolation
    auctions =
      Auction
      |> TenantScope.scope(tenant_id)
      |> BidPlatform.Repo.all()

    render(conn, :index, auctions: auctions)
  end

  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    auction = TenantScope.get!(Auction, tenant_id, id)
    render(conn, :show, auction: auction)
  end

  def create(conn, %{"auction" => auction_params}) do
    tenant_id = conn.assigns.tenant_id
    user_id = conn.assigns.current_user.id
    tenant = BidPlatform.Tenants.get_tenant!(tenant_id)

    if BidPlatform.Tenants.Policy.can_create_auction?(tenant) do
      auction_params =
        auction_params
        |> Map.put("tenant_id", tenant_id)
        |> Map.put("created_by", user_id)

      with {:ok, %Auction{} = auction} <- Auctions.create_auction(auction_params) do
        conn
        |> put_status(:created)
        |> render(:show, auction: auction)
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "plan_limit_exceeded", message: "You have reached your monthly auction limit."})
    end
  end

  def update(conn, %{"id" => id, "auction" => auction_params}) do
    tenant_id = conn.assigns.tenant_id
    auction = TenantScope.get!(Auction, tenant_id, id)

    with {:ok, %Auction{} = auction} <- Auctions.update_auction(auction, auction_params) do
      render(conn, :show, auction: auction)
    end
  end

  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    auction = TenantScope.get!(Auction, tenant_id, id)

    with {:ok, %Auction{}} <- Auctions.delete_auction(auction) do
      send_resp(conn, :no_content, "")
    end
  end
end
