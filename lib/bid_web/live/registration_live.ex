defmodule BidPlatformWeb.RegistrationLive do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Tenants.Registration
  alias BidPlatform.Tenants.Tenant
  alias BidPlatform.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    # Restrict registration to Super Admins only
    current_user = socket.assigns[:current_user]

    if current_user && current_user.role == "super_admin" do
      tenant = %BidPlatform.Tenants.Tenant{}
      changeset = BidPlatform.Tenants.Registration.change_org(tenant, %{})

      {:ok,
       socket
       |> assign_form(changeset)
       |> assign(:page_title, "Provision New Organization")}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access. Only platform administrators can provision new tenants.")
       |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 py-8">
      <.link navigate={~p"/super-admin"} class="text-xs font-bold text-white/40 hover:text-white flex items-center gap-2 mb-8 uppercase tracking-widest transition-colors">
        <.icon name="hero-arrow-left" class="w-4 h-4" />
        Back to Command Center
      </.link>

      <div class="glass p-12 rounded-3xl space-y-8">
        <div class="text-center">
          <div class="w-16 h-16 rounded-2xl bg-indigo-500/20 mx-auto flex items-center justify-center mb-6 border border-indigo-500/30">
            <.icon name="hero-building-office-2" class="w-8 h-8 text-indigo-400" />
          </div>
          <h1 class="text-4xl font-black text-white text-glow mb-2">Provision Organization</h1>
          <p class="text-white/60">Initialize a new isolated environment and admin account.</p>
        </div>

        <.form for={@form} phx-submit="register" class="space-y-6">
          <div class="grid grid-cols-1 gap-y-6">
            <header class="border-b border-white/10 pb-2">
              <span class="text-indigo-400 font-bold text-xs uppercase tracking-widest">Environment Details</span>
            </header>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Tenant Name</label>
              <.input field={@form[:name]} placeholder="e.g. Acme Auctions" class="glass-dark border-white/10 text-white" />
            </div>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Subdomain Prefix</label>
              <div class="flex items-center">
                <.input field={@form[:subdomain]} placeholder="acme" class="rounded-r-none glass-dark border-white/10 text-white flex-1" />
                <span class="bg-white/5 border border-l-0 border-white/10 px-4 py-3 text-white/40 rounded-r-xl font-mono text-sm leading-6">
                  .bidapp.sh
                </span>
              </div>
            </div>

            <header class="border-b border-white/10 pb-2 pt-4">
              <span class="text-indigo-400 font-bold text-xs uppercase tracking-widest">Primary Administrator</span>
            </header>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Admin Email</label>
              <input type="email" name="user[email]" class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all" required />
            </div>

            <div>
              <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Temporary Password</label>
              <input type="password" name="user[password]" class="w-full bg-black/20 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all" required />
            </div>
          </div>

          <button type="submit" class="w-full btn btn-primary py-4 mt-8 rounded-xl font-black text-lg shadow-xl shadow-indigo-500/20">
            Provision Environment
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
         |> put_flash(:info, "Organization #{tenant.name} provisioned successfully!")
         |> redirect(to: ~p"/super-admin")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :tenant))
  end
end
