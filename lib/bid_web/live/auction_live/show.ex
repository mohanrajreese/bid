defmodule BidPlatformWeb.AuctionLive.Show do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Auctions
  alias BidPlatform.Bidding
  alias BidPlatform.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Mount current user is already handled by live_session on_mount
    current_user = socket.assigns.current_user

    if current_user do
      auction = Auctions.get_auction(current_user.tenant_id, id)

      if auction do
        if connected?(socket) do
          BidPlatformWeb.Endpoint.subscribe("tenant:#{current_user.tenant_id}:auction:#{id}")
        end

        {:ok,
         socket
         |> assign(:auction, auction)
         |> assign(:tenant_id, current_user.tenant_id)
         |> assign(:bid_amount, "")
         |> assign(:error_message, nil)
         |> assign(:page_title, auction.title)}
      else
        {:ok,
         socket
         |> put_flash(:error, "Auction not found or unauthorized access.")
         |> redirect(to: ~p"/auctions")}
      end
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("place_bid", %{"amount" => amount}, socket) do
    case Decimal.parse(amount) do
      {value, ""} ->
        case Bidding.place_bid(socket.assigns.tenant_id, socket.assigns.auction.id, socket.assigns.current_user.id, value) do
          {:ok, %{auction: updated_auction}} ->
            {:noreply, assign(socket, auction: updated_auction, bid_amount: "", error_message: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, error_message: inspect(reason))}
        end

      _ ->
        {:noreply, assign(socket, error_message: "Invalid amount")}
    end
  end

  @impl true
  def handle_info(%{event: "bid:new", payload: payload}, socket) do
    updated_auction = %{socket.assigns.auction |
      current_price: payload.current_price,
      bid_count: payload.bid_count
    }
    {:noreply,
      socket
      |> assign(auction: updated_auction)
      |> put_flash(:info, "New bid placed: $#{payload.amount}!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <!-- Main Auction Info -->
      <div class="lg:col-span-2 space-y-6">
        <div class="glass rounded-3xl p-8 space-y-4">
          <div class="flex justify-between items-start">
            <h1 class="text-3xl font-black text-white text-glow">{@auction.title}</h1>
            <span class="px-4 py-1 rounded-full text-sm font-bold bg-primary/20 text-primary border border-primary/30">
              {@auction.status}
            </span>
          </div>
          <p class="text-white/70 text-lg leading-relaxed">{@auction.description}</p>

          <div class="grid grid-cols-3 gap-4 pt-6 border-t border-white/10">
            <div>
              <span class="text-white/40 text-xs uppercase font-bold tracking-widest">Start Price</span>
              <p class="text-xl font-bold text-white">${@auction.start_price}</p>
            </div>
            <div>
              <span class="text-white/40 text-xs uppercase font-bold tracking-widest">Min Increment</span>
              <p class="text-xl font-bold text-white">${@auction.min_increment}</p>
            </div>
            <div>
              <span class="text-white/40 text-xs uppercase font-bold tracking-widest">End Time</span>
              <p class="text-sm font-bold text-white font-mono">{@auction.end_time |> Calendar.strftime("%c")}</p>
            </div>
          </div>
        </div>

        <div class="glass rounded-3xl p-8">
          <h2 class="text-xl font-bold text-white mb-6">Live Activity</h2>
          <div class="space-y-4">
            <div class="flex items-center justify-between p-4 rounded-xl bg-white/5 border border-white/10">
              <span class="text-white/80">Total Bids</span>
              <span class="px-3 py-1 rounded-lg bg-accent/20 text-accent font-bold">{@auction.bid_count}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Bidding Sidebar -->
      <div class="space-y-6">
        <%= if @current_user.role == "bidder" do %>
          <div class="glass-dark rounded-3xl p-8 border-primary/30 relative overflow-hidden">
            <div class="absolute -top-10 -right-10 w-32 h-32 bg-primary/20 blur-3xl rounded-full"></div>

            <div class="relative z-10 text-center space-y-2 mb-8">
              <span class="text-primary font-bold text-sm uppercase tracking-widest">Current Price</span>
              <div class="text-5xl font-black text-white tracking-tight text-glow">
                ${@auction.current_price}
              </div>
            </div>

            <form phx-submit="place_bid" class="space-y-4">
              <div class="space-y-1">
                <label class="text-white/50 text-xs font-bold pl-1">YOUR BID AMOUNT</label>
                <input
                  type="number"
                  name="amount"
                  step="0.01"
                  value={@bid_amount}
                  placeholder={"Min. $#{Decimal.add(@auction.current_price, @auction.min_increment)}"}
                  class="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all"
                />
              </div>

              <%= if @error_message do %>
                <p class="text-error text-xs font-bold bg-error/10 p-2 rounded-lg border border-error/20">
                  {@error_message}
                </p>
              <% end %>

              <button type="submit" class="w-full btn-premium py-4">
                Place Bid Now
              </button>
            </form>

            <p class="mt-6 text-center text-white/40 text-[10px] uppercase font-bold tracking-tighter">
              Secure multi-tenant encrypted transaction
            </p>
          </div>
        <% else %>
          <div class="glass-dark rounded-3xl p-8 border-indigo-500/30 text-center space-y-4">
            <div class="w-16 h-16 bg-indigo-500/10 rounded-2xl flex items-center justify-center mx-auto border border-indigo-500/20">
              <.icon name="hero-shield-check" class="w-8 h-8 text-indigo-400" />
            </div>
            <div>
              <h3 class="text-lg font-bold text-white">Admin View</h3>
              <p class="text-white/50 text-sm mt-1">You are viewing this auction as an administrator. Only registered bidders can place bids.</p>
            </div>
            <%= if @current_user.role == "admin" do %>
              <.link navigate={~p"/tenant-admin"} class="block w-full py-3 rounded-xl bg-white/5 border border-white/10 text-white font-bold hover:bg-white/10 transition-all text-sm">
                Back to Command Center
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
