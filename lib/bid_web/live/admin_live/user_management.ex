defmodule BidPlatformWeb.AdminLive.UserManagement do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Accounts
  alias BidPlatform.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    # In a real app, verify the 'admin' role here
    current_user = socket.assigns[:current_user]

    if current_user && current_user.role == "admin" do
      users = Accounts.list_users(current_user.tenant_id)
      changeset = Accounts.change_user(%User{tenant_id: current_user.tenant_id})

      {:ok,
       socket
       |> assign(:users, users)
       |> assign_form(changeset)
       |> assign(:page_title, "Member Management")}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <header class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-black text-white tracking-tight">Member <span class="text-primary">Management</span></h1>
          <p class="text-white/40 mt-1">Manage your organization's team and bidders.</p>
        </div>
        <button phx-click={show("#add-user-modal")} class="btn btn-primary rounded-xl">
          <.icon name="hero-plus-circle" class="w-4 h-4 mr-2" />
          Add Member
        </button>
      </header>

      <div class="glass-panel overflow-hidden">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-white/5 border-b border-white/10">
              <th class="p-4 text-xs font-bold text-white/50 uppercase tracking-widest pl-6">Member</th>
              <th class="p-4 text-xs font-bold text-white/50 uppercase tracking-widest text-center">Role</th>
              <th class="p-4 text-xs font-bold text-white/50 uppercase tracking-widest text-center">Status</th>
              <th class="p-4 text-xs font-bold text-white/50 uppercase tracking-widest text-right pr-6">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-white/5">
            <%= for user <- @users do %>
              <tr class="hover:bg-white/5 transition-colors">
                <td class="p-4 pl-6">
                  <div class="font-bold text-white">{user.name}</div>
                  <div class="text-xs text-white/40 font-mono">{user.email}</div>
                </td>
                <td class="p-4 text-center">
                  <span class={"px-2 py-1 rounded-lg text-[10px] font-black uppercase tracking-tighter #{if user.role == "admin", do: "bg-primary/20 text-primary", else: "bg-white/10 text-white/60"}"}>
                    {user.role}
                  </span>
                </td>
                <td class="p-4 text-center">
                  <div class="flex items-center justify-center gap-2">
                    <div class={"w-2 h-2 rounded-full #{if user.is_active, do: "bg-success shadow-[0_0_8px_rgba(52,211,153,0.5)]", else: "bg-slate-600"}"}></div>
                    <span class="text-xs text-white/60">{if user.is_active, do: "Active", else: "Inactive"}</span>
                  </div>
                </td>
                <td class="p-4 text-right pr-6">
                  <button
                    :if={user.id != @current_user.id}
                    phx-click="toggle-status"
                    phx-value-id={user.id}
                    class="text-xs font-bold text-white/40 hover:text-white transition-colors"
                  >
                    {if user.is_active, do: "Deactivate", else: "Activate"}
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <!-- Add User Modal -->
      <.modal id="add-user-modal">
        <div class="p-2">
          <h2 class="text-2xl font-black text-white mb-6">Provision New Member</h2>
          <.form for={@form} phx-submit="save-user" class="space-y-4">
            <.input field={@form[:tenant_id]} type="hidden" />

            <div class="space-y-1">
              <label class="text-xs font-bold text-white/50 uppercase pl-1">Display Name</label>
              <.input field={@form[:name]} placeholder="e.g. John Doe" class="glass-dark" required />
            </div>

            <div class="space-y-1">
              <label class="text-xs font-bold text-white/50 uppercase pl-1">Email Address</label>
              <.input field={@form[:email]} type="email" placeholder="john@example.com" class="glass-dark" required />
            </div>

            <div class="space-y-1">
              <label class="text-xs font-bold text-white/50 uppercase pl-1 text-glow">Role</label>
              <div class="glass-dark p-3 rounded-xl border border-white/10 text-white/60 text-sm flex items-center gap-2 italic">
                <.icon name="hero-user" class="w-4 h-4" />
                Participant (Bidder)
              </div>
            </div>

            <div class="space-y-1">
              <label class="text-xs font-bold text-white/50 uppercase pl-1">Initial Password</label>
              <.input field={@form[:password]} type="password" placeholder="Min 8 characters" class="glass-dark" required />
            </div>

            <div class="pt-4">
              <button type="submit" class="w-full btn btn-primary py-4 rounded-xl font-bold">
                Create Bidder Account
              </button>
            </div>
          </.form>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("save-user", %{"user" => user_params}, socket) do
    # Only Bidders can be created by Tenant Admins
    user_params =
      user_params
      |> Map.put("tenant_id", socket.assigns.current_user.tenant_id)
      |> Map.put("role", "bidder")

    case Accounts.create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bidder account created successfully")
         |> push_patch(to: ~p"/tenant-admin/members")
         |> assign(:users, Accounts.list_users(socket.assigns.current_user.tenant_id))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("toggle-status", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.update_user(user, %{is_active: !user.is_active}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:users, Accounts.list_users(socket.assigns.current_user.tenant_id))}

      _ ->
        {:noreply, socket}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
