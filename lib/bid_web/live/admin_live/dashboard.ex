defmodule BidPlatformWeb.AdminLive.Dashboard do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Auctions
  alias BidPlatform.Tenants

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    tenant_id = current_user.tenant_id

    # In a real app, we'd have a separate Metrics module for tenants
    # For now, we'll fetch actual counts from Repo
    import Ecto.Query

    auctions = Auctions.list_auctions(tenant_id)
    bidder_count =
      BidPlatform.Accounts.User
      |> where([u], u.tenant_id == ^tenant_id and u.role == "bidder")
      |> BidPlatform.Repo.aggregate(:count, :id)

    total_volume =
      BidPlatform.Bidding.Bid
      |> join(:inner, [b], a in BidPlatform.Auctions.Auction, on: b.auction_id == a.id)
      |> where([b, a], a.tenant_id == ^tenant_id)
      |> BidPlatform.Repo.aggregate(:sum, :amount) || 0

    {:ok,
     socket
     |> assign(:tenant_id, tenant_id)
     |> assign(:auctions, auctions)
     |> assign(:bidder_count, bidder_count)
     |> assign(:total_volume, total_volume)
     |> assign(:page_title, "Admin Dashboard")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Admin Dashboard")
    |> assign(:auction, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Auction")
    |> assign(:auction, %BidPlatform.Auctions.Auction{})
  end

  @impl true
  def handle_info({BidPlatformWeb.AdminLive.AuctionForm, {:saved, _auction}}, socket) do
    tenant_id = socket.assigns.tenant_id
    auctions = Auctions.list_auctions(tenant_id)
    {:noreply, assign(socket, auctions: auctions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <h1 class="text-3xl font-black text-white text-glow">Admin Command Center</h1>
        <div class="flex items-center gap-4">
          <.link navigate={~p"/tenant-admin/members"} class="btn-premium bg-indigo-500/10 border-indigo-500/20 text-indigo-400 hover:bg-indigo-500/20">
            <div class="flex items-center gap-2">
              <.icon name="hero-users" class="w-5 h-5" />
              Manage Members
            </div>
          </.link>
          <.link patch={~p"/tenant-admin/new"} class="btn-premium">
            <div class="flex items-center gap-2">
              <.icon name="hero-plus-circle" class="w-5 h-5" />
              Create New Auction
            </div>
          </.link>
        </div>
      </div>

      <.modal :if={@live_action in [:new]} id="auction-modal" show on_cancel={JS.patch(~p"/tenant-admin")}>
        <.live_component
          module={BidPlatformWeb.AdminLive.AuctionForm}
          id={@auction.id || :new}
          title={@page_title}
          action={@live_action}
          auction={@auction}
          tenant_id={@tenant_id}
          current_user={@current_user}
          patch={~p"/tenant-admin"}
        />
      </.modal>

      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <.stat_card title="Total Volume" value={"$#{@total_volume}"} icon="hero-banknotes" />
        <.stat_card title="Active Auctions" value={Enum.count(@auctions)} icon="hero-rocket-launch" />
        <.stat_card title="Unique Bidders" value={@bidder_count} icon="hero-users" />
        <.stat_card title="Success Rate" value="100%" icon="hero-check-badge" />
      </div>

      <!-- Auction Table -->
      <div class="glass rounded-3xl overflow-hidden animate-float">
        <table class="w-full text-left">
          <thead class="bg-white/5 border-b border-white/10">
            <tr>
              <th class="px-6 py-4 text-xs font-bold text-white/50 uppercase tracking-widest">Auction</th>
              <th class="px-6 py-4 text-xs font-bold text-white/50 uppercase tracking-widest">Type</th>
              <th class="px-6 py-4 text-xs font-bold text-white/50 uppercase tracking-widest">Price</th>
              <th class="px-6 py-4 text-xs font-bold text-white/50 uppercase tracking-widest">Status</th>
              <th class="px-6 py-4 text-xs font-bold text-white/50 uppercase tracking-widest">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-white/5">
            <%= for auction <- @auctions do %>
              <tr class="hover:bg-white/5 transition-colors">
                <td class="px-6 py-4">
                  <div class="text-sm font-bold text-white">{auction.title}</div>
                  <div class="text-xs text-white/40">{auction.id |> String.slice(0, 8)}</div>
                </td>
                <td class="px-6 py-4">
                  <span class="text-xs font-mono text-white/60">{auction.type}</span>
                </td>
                <td class="px-6 py-4">
                  <div class="text-sm font-bold text-white">${auction.current_price}</div>
                  <div class="text-[10px] text-white/40">{auction.bid_count} bids</div>
                </td>
                <td class="px-6 py-4">
                  <span class="px-2 py-1 rounded-md text-[10px] font-black uppercase bg-success/20 text-success border border-success/30">
                    {auction.status}
                  </span>
                </td>
                <td class="px-6 py-4">
                  <div class="flex gap-2">
                    <button class="btn btn-xs glass border-white/10 text-white">Edit</button>
                    <a href={~p"/auctions/#{auction.id}"} class="btn btn-xs glass-dark border-white/10 text-white">View</a>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="glass rounded-2xl p-6 border-white/10">
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center border border-primary/20">
          <.icon name={@icon} class="w-6 h-6 text-primary" />
        </div>
        <div>
          <span class="text-white/40 text-xs font-bold uppercase tracking-widest">{@title}</span>
          <p class="text-2xl font-black text-white">{@value}</p>
        </div>
      </div>
    </div>
    """
  end
end
