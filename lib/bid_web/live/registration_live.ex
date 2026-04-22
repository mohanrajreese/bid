defmodule BidPlatformWeb.RegistrationLive do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Tenants.Registration
  alias BidPlatform.Tenants.ProvisioningForm

  @impl true
  def mount(_params, _session, socket) do
    # Restrict registration to Super Admins only
    current_user = socket.assigns[:current_user]

    if current_user && current_user.role == "super_admin" do
      changeset = ProvisioningForm.changeset(%ProvisioningForm{}, %{})

      {:ok,
       socket
       |> assign_form(changeset)
       |> assign(:provisioned_tenant, nil)
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

      <%= if @provisioned_tenant do %>
        <div class="glass p-12 rounded-3xl space-y-8 animate-in zoom-in duration-500 text-center">
          <div class="w-20 h-20 rounded-full bg-success/20 mx-auto flex items-center justify-center border border-success/30 mb-4">
            <.icon name="hero-check-badge" class="w-12 h-12 text-success" />
          </div>
          <h2 class="text-3xl font-black text-white">Provisioning Successful!</h2>
          <p class="text-white/60">
            Organization <span class="text-white font-bold">{@provisioned_tenant.name}</span> has been created.
          </p>
          <div class="bg-black/20 rounded-2xl p-6 border border-white/5 inline-block text-left">
            <p class="text-xs font-bold text-white/40 uppercase mb-2">Access Details</p>
            <p class="text-sm text-white">URL: <span class="text-primary font-mono">{@provisioned_tenant.subdomain}.bidapp.sh</span></p>
          </div>
          <div class="pt-8">
            <.link navigate={~p"/super-admin"} class="btn btn-primary rounded-xl px-12">
              Done
            </.link>
          </div>
        </div>
      <% else %>
        <div class="glass p-12 rounded-3xl space-y-8">
          <div class="text-center">
            <div class="w-16 h-16 rounded-2xl bg-indigo-500/20 mx-auto flex items-center justify-center mb-6 border border-indigo-500/30">
              <.icon name="hero-building-office-2" class="w-8 h-8 text-indigo-400" />
            </div>
            <h1 class="text-4xl font-black text-white text-glow mb-2">Provision Organization</h1>
            <p class="text-white/60">Initialize a new isolated environment and admin account.</p>
          </div>

          <.form for={@form} phx-submit="provision" class="space-y-6">
            <div class="grid grid-cols-1 gap-y-6">
              <header class="border-b border-white/10 pb-2">
                <span class="text-indigo-400 font-bold text-xs uppercase tracking-widest">Environment Details</span>
              </header>

              <div>
                <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Tenant Name</label>
                <.input field={@form[:name]} placeholder="e.g. Acme Auctions" class="glass-dark border-white/10 text-white" required />
              </div>

              <div>
                <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Subdomain Prefix</label>
                <div class="flex items-center">
                  <.input field={@form[:subdomain]} placeholder="acme" class="rounded-r-none glass-dark border-white/10 text-white flex-1" required />
                  <span class="bg-white/5 border border-l-0 border-white/10 px-4 py-3 text-white/40 rounded-r-xl font-mono text-sm leading-6">
                    .bidapp.sh
                  </span>
                </div>
              </div>

              <header class="border-b border-white/10 pb-2 pt-4">
                <span class="text-indigo-400 font-bold text-xs uppercase tracking-widest">Primary Administrator</span>
              </header>

              <div>
                <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Admin Full Name</label>
                <.input field={@form[:admin_name]} placeholder="e.g. John Doe" class="glass-dark border-white/10 text-white" required />
              </div>

              <div>
                <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Admin Email</label>
                <.input field={@form[:admin_email]} type="email" placeholder="admin@org.com" class="glass-dark border-white/10 text-white" required />
              </div>

              <div>
                <label class="block text-sm font-bold text-white/50 mb-1 pl-1 uppercase tracking-tighter">Temporary Password</label>
                <.input field={@form[:admin_password]} type="password" class="glass-dark border-white/10 text-white" required />
              </div>
            </div>

            <button type="submit" class="w-full btn btn-primary py-4 mt-8 rounded-xl font-black text-lg shadow-xl shadow-indigo-500/20 uppercase tracking-widest">
              Provision Environment
            </button>
          </.form>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("provision", %{"provisioning_form" => params}, socket) do
    # Log incoming parameters to debug
    IO.inspect(params, label: "PROVISIONING PARAMS")

    changeset = ProvisioningForm.changeset(%ProvisioningForm{}, params)

    if changeset.valid? do
      # Convert virtual form to real registration inputs
      tenant_params = %{"name" => params["name"], "subdomain" => params["subdomain"]}
      user_params = %{
        "name" => params["admin_name"],
        "email" => params["admin_email"],
        "password" => params["admin_password"]
      }

      case Registration.register_org(tenant_params, user_params) do
        {:ok, %{tenant: tenant}} ->
          {:noreply, assign(socket, :provisioned_tenant, tenant)}

        {:error, %Ecto.Changeset{} = failed_changeset} ->
          # Add errors from the failed step to our provisioning form
          IO.inspect(failed_changeset.errors, label: "DB FAIL ERRORS")

          # Map DB Errors (like uniqueness) back to the form
          form_changeset = add_db_errors(changeset, failed_changeset)
          {:noreply, assign_form(socket, form_changeset)}
      end
    else
      {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  defp add_db_errors(form_changeset, db_changeset) do
    Enum.reduce(db_changeset.errors, form_changeset, fn {field, {msg, opts}}, acc ->
      # Map field names if they differ
      mapped_field = case field do
        :email -> :admin_email
        :password -> :admin_password
        :name -> :admin_name
        other -> other
      end
      Ecto.Changeset.add_error(acc, mapped_field, msg, opts)
    end)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :provisioning_form))
  end
end
