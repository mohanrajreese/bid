defmodule BidPlatformWeb.RegistrationLive do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Tenants.Registration
  alias BidPlatform.Tenants.Tenant
  alias BidPlatform.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tenant_changeset, Tenant.changeset(%Tenant{}, %{}))
     |> assign(:user_changeset, User.registration_changeset(%User{}, %{}))
     |> assign(:page_title, "Register your Organization")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8">
      <div class="glass p-12 rounded-3xl space-y-8 animate-float">
        <div class="text-center">
          <h1 class="text-4xl font-black text-white text-glow mb-2">Join BidPlatform</h1>
          <p class="text-white/60">Launch your own multi-tenant bidding environment in seconds.</p>
        </div>

        <.form for={@tenant_changeset} phx-submit="register" class="space-y-6">
          <div class="grid grid-cols-1 gap-y-6">
            <header class="border-b border-white/10 pb-2">
              <span class="text-primary font-bold text-xs uppercase tracking-widest">Organization Details</span>
            </header>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1">ORG NAME</label>
              <.input field={@tenant_changeset[:name]} placeholder="e.g. Acme Corp" class="glass-dark border-white/10 text-white" />
            </div>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1">SUBDOMAIN</label>
              <div class="flex items-center">
                <.input field={@tenant_changeset[:subdomain]} placeholder="acme" class="rounded-r-none glass-dark border-white/10 text-white flex-1" />
                <span class="bg-white/5 border border-l-0 border-white/10 px-4 py-3 text-white/40 rounded-r-xl font-mono text-sm leading-6">
                  .bidapp.sh
                </span>
              </div>
              <p class="mt-2 text-[10px] text-white/30 text-right uppercase font-bold tracking-tighter">must be unique and lowercase</p>
            </div>

            <header class="border-b border-white/10 pb-2 pt-4">
              <span class="text-primary font-bold text-xs uppercase tracking-widest">Admin Account</span>
            </header>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1">EMAIL</label>
              <input type="email" name="user[email]" class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all" required />
            </div>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1">PASSWORD</label>
              <input type="password" name="user[password]" class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all" required />
            </div>
          </div>

          <button type="submit" class="w-full btn-premium py-4 mt-8">
            Create My Environment
          </button>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("register", %{"tenant" => tenant_params, "user" => user_params}, socket) do
    case Registration.register_org(tenant_params, user_params) do
      {:ok, %{tenant: tenant}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization #{tenant.name} registered successfully!")
         |> redirect(to: ~p"/auth/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, :tenant_changeset, changeset)}
    end
  end
end
