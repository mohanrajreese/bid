defmodule BidPlatformWeb.AdminLive.Dashboard do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Auctions
  alias BidPlatform.Tenants

  @impl true
  def mount(_params, _session, socket) do
    tenant = Tenants.list_tenants() |> List.first()
    auctions = if tenant, do: Auctions.list_auctions(tenant.id), else: []

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:auctions, auctions)
     |> assign(:page_title, "Admin Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <h1 class="text-3xl font-black text-white text-glow">Admin Command Center</h1>
        <button class="btn-premium" phx-click="new_auction">
          + Create New Auction
        </button>
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <.stat_card title="Total Volume" value="$128,400" icon="hero-banknotes" />
        <.stat_card title="Active Auctions" value={Enum.count(@auctions)} icon="hero-rocket-launch" />
        <.stat_card title="Unique Bidders" value="1,042" icon="hero-users" />
        <.stat_card title="Success Rate" value="94%" icon="hero-check-badge" />
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
