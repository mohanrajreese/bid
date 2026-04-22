defmodule BidPlatformWeb.SuperAdminLive.Dashboard do
  use BidPlatformWeb, :live_view

  alias BidPlatform.Metrics
  alias BidPlatform.AuditLogs

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok

    # In a real app, we would verify the super_admin role here via a plug or helper
    # For now, we assume the user is authorized if they hit this route.

    stats = Metrics.get_system_stats()
    tenants = Metrics.list_tenant_overviews()
    logs = AuditLogs.list_all_logs(limit: 10)

    {:ok,
     socket
     |> assign(:page_title, "Super Admin Command Center")
     |> assign(:stats, stats)
     |> assign(:tenants, tenants)
     |> assign(:logs, logs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 animate-in fade-in duration-700">
      <header>
        <h1 class="text-4xl font-black text-white tracking-tight">
          Command <span class="text-indigo-400">Center</span>
        </h1>
        <p class="text-slate-400 mt-2">Overseeing the global bidding ecosystem.</p>
      </header>

      <!-- KPI Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <.kpi_card title="Organizations" value={@stats.total_tenants} icon="hero-building-office" color="text-blue-400" />
        <.kpi_card title="Live Auctions" value={@stats.total_auctions} icon="hero-bolt" color="text-amber-400" />
        <.kpi_card title="Total Bids" value={@stats.total_bids} icon="hero-circle-stack" color="text-emerald-400" />
        <.kpi_card title="Total Users" value={@stats.total_users} icon="hero-users" color="text-indigo-400" />
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Organizations Table -->
        <div class="lg:col-span-2 glass-panel p-6">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-xl font-bold text-white flex items-center gap-2">
              <.icon name="hero-building-library" class="w-5 h-5 text-indigo-400" />
              Recent Organizations
            </h2>
            <.link
              navigate={~p"/register"}
              class="btn btn-sm btn-primary rounded-xl flex items-center gap-2"
            >
              <.icon name="hero-plus-circle" class="w-4 h-4" />
              Create New Org
            </.link>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left">
              <thead>
                <tr class="text-slate-500 border-b border-white/5">
                  <th class="pb-3 pl-4">Name</th>
                  <th class="pb-3 text-center">Status</th>
                  <th class="pb-3 text-center">Users</th>
                  <th class="pb-3 text-center">Auctions</th>
                  <th class="pb-3 text-right pr-4">Joined</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <%= for tenant <- @tenants do %>
                  <tr class="hover:bg-white/5 transition-colors group">
                    <td class="py-4 pl-4">
                      <div class="font-semibold text-white group-hover:text-indigo-400 transition-colors">
                        {tenant.name}
                      </div>
                      <div class="text-xs text-slate-500 font-mono">{tenant.subdomain}.bidapp.sh</div>
                    </td>
                    <td class="py-4 text-center">
                      <span class={"px-2 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider #{if tenant.is_active, do: "bg-emerald-500/10 text-emerald-400", else: "bg-rose-500/10 text-rose-400"}"}>
                        {if tenant.is_active, do: "Active", else: "Suspended"}
                      </span>
                    </td>
                    <td class="py-4 text-center text-slate-300 font-mono">{tenant.user_count}</td>
                    <td class="py-4 text-center text-slate-300 font-mono">{tenant.auction_count}</td>
                    <td class="py-4 text-right pr-4 text-slate-500 text-sm">
                      {Calendar.strftime(tenant.inserted_at, "%b %d, %Y")}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <!-- System Pulse (Logs) -->
        <div class="glass-panel p-6">
          <h2 class="text-xl font-bold text-white mb-6 flex items-center gap-2">
            <.icon name="hero-activity" class="w-5 h-5 text-amber-400" />
            System Pulse
          </h2>

          <div class="space-y-4">
            <%= for log <- @logs do %>
              <div class="border-l-2 border-indigo-500/30 pl-4 py-1">
                <div class="text-sm text-white font-semibold">
                  <span class="text-indigo-400 font-mono text-xs capitalize">[{log.action}]</span>
                  {if log.user, do: log.user.name, else: "System"}
                </div>
                <div class="text-xs text-slate-500 flex justify-between items-center mt-1">
                  <span>In {log.tenant.name}</span>
                  <span>{time_ago(log.inserted_at)}</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp kpi_card(assigns) do
    ~H"""
    <div class="glass-panel p-6 flex items-start gap-4 hover:border-white/20 transition-all duration-300 transform hover:-translate-y-1">
      <div class={"p-3 rounded-xl bg-white/5 #{@color}"}>
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-xs font-bold text-slate-500 uppercase tracking-widest leading-none">{@title}</p>
        <p class="text-2xl font-black text-white mt-1">{@value}</p>
      </div>
    </div>
    """
  end

  defp time_ago(dt) do
    # Simple relative time
    diff = DateTime.diff(DateTime.utc_now(), DateTime.from_naive!(dt, "Etc/UTC"))

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end
