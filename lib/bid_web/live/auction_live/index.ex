defmodule BidPlatformWeb.AuctionLive.Index do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Auctions
  alias BidPlatform.Tenants

  @impl true
  def mount(_params, _session, socket) do
    # Mount current user is already handled by live_session on_mount
    current_user = socket.assigns.current_user

    if current_user do
      auctions = Auctions.list_auctions(current_user.tenant_id)

      {:ok,
       socket
       |> assign(:tenant_id, current_user.tenant_id)
       |> assign(:auctions, auctions)
       |> assign(:search_query, "")
       |> assign(:page_title, "Live Auctions")}
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    # Simple search filtering
    all_auctions = Auctions.list_auctions(socket.assigns.tenant_id)

    filtered = if query == "" do
      all_auctions
    else
      Enum.filter(all_auctions, fn a ->
        String.contains?(String.downcase(a.title), String.downcase(query)) ||
        String.contains?(String.downcase(a.description || ""), String.downcase(query))
      end)
    end

    {:noreply,
     socket
     |> assign(auctions: filtered)
     |> assign(search_query: query)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 animate-float">
      <div class="flex flex-col md:flex-row items-center justify-between gap-4 mb-12">
        <div>
          <h1 class="text-4xl font-black text-white text-glow">Live Auctions</h1>
          <p class="text-white/60 mt-2">Discover and participate in high-stakes bidding.</p>
        </div>
        <div class="flex items-center gap-2 w-full md:w-auto">
          <form phx-change="search" class="relative flex-grow md:w-64">
             <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40" />
             <input type="text" name="query" value={@search_query} placeholder="Search auctions..." class="w-full bg-white/5 border border-white/10 rounded-xl pl-10 pr-4 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all font-mono" />
          </form>
          <div class="flex items-center bg-white/5 rounded-xl border border-white/10 p-1">
             <button class="px-3 py-1 text-[10px] font-bold text-white bg-primary rounded-lg">All</button>
             <button class="px-3 py-1 text-[10px] font-bold text-white/40 hover:text-white">Active</button>
             <button class="px-3 py-1 text-[10px] font-bold text-white/40 hover:text-white">Ended</button>
          </div>
        </div>
      </div>

      <%= if Enum.empty?(@auctions) do %>
        <div class="glass rounded-2xl p-12 text-center border-white/5">
          <.icon name="hero-scale" class="w-12 h-12 text-white/20 mx-auto" />
          <h3 class="mt-4 text-xl font-semibold text-white">No matching auctions</h3>
          <p class="mt-2 text-white/50">Try a different search term or check back later.</p>
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
    <div class="glass group relative rounded-2xl p-6 transition-all duration-300 hover:scale-[1.02] hover:bg-white/20 border-white/5">
      <div class="flex justify-between items-start mb-4">
        <span class="px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest bg-primary/20 text-primary border border-primary/30">
          {@auction.type}
        </span>
        <div class="flex items-center text-white/50 text-[10px] font-bold uppercase tracking-widest">
          <div class="w-2 h-2 rounded-full bg-success mr-2 animate-pulse"></div>
          Live
        </div>
      </div>

      <h3 class="text-xl font-bold text-white mb-2 group-hover:text-primary transition-colors">
        {@auction.title}
      </h3>

      <p class="text-white/60 text-sm line-clamp-2 mb-6 h-10">
        {@auction.description}
      </p>

      <div class="flex items-end justify-between">
        <div>
          <span class="text-white/40 text-[10px] block uppercase font-bold tracking-widest">Current Bid</span>
          <span class="text-2xl font-black text-white text-glow">
            ${@auction.current_price}
          </span>
        </div>
        <.link navigate={~p"/auctions/#{@auction.id}"} class="btn btn-sm glass-dark text-white border-white/10 hover:bg-primary hover:text-white transition-all rounded-xl">
          Participate
        </.link>
      </div>

      <div class="mt-4 pt-4 border-t border-white/5 flex items-center justify-between text-[10px] font-bold uppercase tracking-widest text-white/40">
        <div class="flex items-center gap-1">
          <.icon name="hero-user-group" class="w-3 h-3" />
          <span>{@auction.bid_count} Bids</span>
        </div>
        <span>Ends in 2d 4h</span>
      </div>
    </div>
    """
  end
end
