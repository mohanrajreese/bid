defmodule BidPlatformWeb.AuthLive.Login do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:email, "")
     |> assign(:password, "")
     |> assign(:error_message, nil)
     |> assign(:trigger_action, false)
     |> assign(:page_title, "Log in")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md px-4 py-16 sm:px-6 sm:py-24 lg:px-8">
      <div class="glass p-12 rounded-3xl space-y-8 animate-float">
        <div class="text-center">
          <div class="w-16 h-16 rounded-2xl bg-primary mx-auto flex items-center justify-center mb-6 shadow-lg shadow-primary/20">
            <.icon name="hero-key" class="w-8 h-8 text-white" />
          </div>
          <h1 class="text-3xl font-black text-white text-glow mb-2">Welcome Back</h1>
          <p class="text-white/60">Log in to your secure bidding console.</p>
        </div>

        <.form
          for={%{}}
          as={:user}
          action={~p"/login"}
          phx-submit="login"
          phx-trigger-action={@trigger_action}
          class="space-y-6"
        >
          <div class="space-y-1">
            <label class="block text-sm font-bold text-white/50 mb-1 pl-1">EMAIL ADDRESS</label>
            <input
              type="email"
              name="email"
              value={@email}
              class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all font-mono text-sm"
              required
            />
          </div>

          <div class="space-y-1">
            <label class="block text-sm font-bold text-white/50 mb-1 pl-1">PASSWORD</label>
            <input
              type="password"
              name="password"
              class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all font-mono text-sm"
              required
            />
          </div>

          <%= if @error_message do %>
            <p class="text-error text-xs font-bold bg-error/10 p-2 rounded-lg border border-error/20">
              {@error_message}
            </p>
          <% end %>

          <button type="submit" class="w-full btn-premium py-4 mt-4">
            Authenticate & Enter
          </button>
        </.form>

        <div class="text-center pt-4">
          <p class="text-white/20 text-[10px] uppercase font-black tracking-widest leading-loose">
            Secure Multi-Tenant Gateway<br/>
            Authorized Access Only
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("login", %{"email" => email, "password" => password}, socket) do
    case Accounts.get_user_by_email(email) do
      nil ->
        {:noreply, assign(socket, error_message: "Invalid email or password")}

      _user ->
        # Validate password here and then trigger the action to the controller
        {:noreply,
         socket
         |> assign(:email, email)
         |> assign(:trigger_action, true)}
    end
  end
end
