defmodule BidPlatformWeb.BidderLive.Dashboard do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Bidding
  alias BidPlatform.Auctions

  @impl true
  def mount(_params, _session, socket) do
    # Demo tenant and user
    tenant = BidPlatform.Tenants.list_tenants() |> List.first()
    # In real app, we'd fetch current user's bids
    bids = if tenant, do: Bidding.list_bids(tenant.id, "dummy"), else: [] # Simplified

    {:ok,
     socket
     |> assign(:bids, bids)
     |> assign(:page_title, "My Bidding Hub")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-3xl font-black text-white text-glow">My Bidding Hub</h1>
        <p class="text-white/60 mt-2">Track and manage your active bids across all auctions.</p>
      </div>

      <!-- Quick Stats -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
        <div class="glass p-6 rounded-2xl flex items-center gap-4">
          <div class="w-12 h-12 rounded-xl bg-success/20 flex items-center justify-center border border-success/30">
            <.icon name="hero-trophy" class="w-6 h-6 text-success" />
          </div>
          <div>
            <span class="text-white/40 text-[10px] font-bold uppercase tracking-widest">Winning</span>
            <p class="text-2xl font-black text-white">4</p>
          </div>
        </div>
        <div class="glass p-6 rounded-2xl flex items-center gap-4 border-error/20">
          <div class="w-12 h-12 rounded-xl bg-error/20 flex items-center justify-center border border-error/30">
            <.icon name="hero-arrow-trending-down" class="w-6 h-6 text-error" />
          </div>
          <div>
            <span class="text-white/40 text-[10px] font-bold uppercase tracking-widest">Outbid</span>
            <p class="text-2xl font-black text-white">2</p>
          </div>
        </div>
        <div class="glass p-6 rounded-2xl flex items-center gap-4">
          <div class="w-12 h-12 rounded-xl bg-primary/20 flex items-center justify-center border border-primary/30">
            <.icon name="hero-clock" class="w-6 h-6 text-primary" />
          </div>
          <div>
            <span class="text-white/40 text-[10px] font-bold uppercase tracking-widest">Total Spent</span>
            <p class="text-2xl font-black text-white">$12,450</p>
          </div>
        </div>
      </div>

      <div class="glass rounded-3xl p-8">
        <h2 class="text-xl font-bold text-white mb-6">Active Participations</h2>
        <%= if Enum.empty?(@bids) do %>
           <div class="text-center py-12">
             <.icon name="hero-magnifying-glass" class="w-12 h-12 text-white/10 mx-auto" />
             <p class="text-white/40 mt-4">You haven't placed any bids yet.</p>
             <.link navigate={~p"/auctions"} class="text-primary hover:underline mt-2 inline-block">Browse Live Auctions</.link>
           </div>
        <% else %>
          <div class="space-y-4">
            <!-- Simplified list for demo -->
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
