defmodule BidPlatformWeb.Router do
  use BidPlatformWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BidPlatformWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", BidPlatformWeb do
    pipe_through :api
    get "/health", HealthController, :check
  end

  scope "/", BidPlatformWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug BidPlatformWeb.Plugs.Auth
  end

  scope "/api/v1", BidPlatformWeb do
    pipe_through :authenticated_api

    resources "/auctions", AuctionController, except: [:new, :edit] do
      resources "/bids", BidController, only: [:create, :index]
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:bid, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BidPlatformWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
