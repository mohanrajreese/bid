defmodule BidPlatformWeb.AuctionLive.Index do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Auctions
  alias BidPlatform.Tenants

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to auction updates
      # Phoenix.PubSub.subscribe(BidPlatform.PubSub, "auctions")
    end

    # For demo, we'll pick the first tenant if one exists
    tenant = Tenants.list_tenants() |> List.first()

    auctions = if tenant, do: Auctions.list_auctions(tenant.id), else: []

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:auctions, auctions)
     |> assign(:page_title, "Active Auctions")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 animate-float">
      <div class="flex items-end justify-between">
        <div>
          <h1 class="text-4xl font-extrabold text-white tracking-tight sm:text-5xl text-glow">
            Live Auctions
          </h1>
          <p class="mt-2 text-lg text-white/60">
            Real-time multi-tenant bidding platform.
          </p>
        </div>
        <div class="hidden sm:block">
          <button class="btn-premium">
            Create Auction
          </button>
        </div>
      </div>

      <%= if Enum.empty?(@auctions) do %>
        <div class="glass rounded-2xl p-12 text-center">
          <.icon name="hero-scale" class="w-12 h-12 text-white/20 mx-auto" />
          <h3 class="mt-4 text-xl font-semibold text-white">No active auctions</h3>
          <p class="mt-2 text-white/50">Be the first to create one!</p>
        </div>
      <% else %>
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <%= for auction <- @auctions do %>
            <.auction_card auction={auction} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp auction_card(assigns) do
    ~H"""
    <div class="glass group relative rounded-2xl p-6 transition-all duration-300 hover:scale-[1.02] hover:bg-white/20">
      <div class="flex justify-between items-start mb-4">
        <span class="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-primary/20 text-primary border border-primary/30">
          {@auction.type}
        </span>
        <div class="flex items-center text-white/50 text-xs">
          <.icon name="hero-clock" class="w-4 h-4 mr-1" />
          <span class="font-mono">Live</span>
        </div>
      </div>

      <h3 class="text-xl font-bold text-white mb-2 group-hover:text-primary transition-colors">
        {@auction.title}
      </h3>

      <p class="text-white/60 text-sm line-clamp-2 mb-6">
        {@auction.description}
      </p>

      <div class="flex items-end justify-between">
        <div>
          <span class="text-white/40 text-xs block uppercase font-bold tracking-widest">Current Bid</span>
          <span class="text-2xl font-black text-white">
            ${@auction.current_price}
          </span>
        </div>
        <a href={~p"/auctions/#{@auction.id}"} class="btn btn-sm glass-dark text-white border-white/20">
          View Detail
        </a>
      </div>

      <div class="mt-4 pt-4 border-t border-white/5 flex items-center justify-between text-xs text-white/40">
        <span>{@auction.bid_count} bids placed</span>
        <span>Ends in 2d 4h</span>
      </div>
    </div>
    """
  end
end
