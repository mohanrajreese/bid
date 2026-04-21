defmodule BidPlatform.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BidPlatformWeb.Telemetry,
      BidPlatform.Repo,
      {DNSCluster, query: Application.get_env(:bid, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BidPlatform.PubSub},
      # Start a worker by calling: BidPlatform.Worker.start_link(arg)
      # {BidPlatform.Worker, arg},
      # Start to serve requests, typically the last entry
      BidPlatformWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BidPlatform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BidPlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
