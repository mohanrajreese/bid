# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :bid,
  namespace: BidPlatform,
  ecto_repos: [BidPlatform.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :bid, BidPlatformWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BidPlatformWeb.ErrorHTML, json: BidPlatformWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BidPlatform.PubSub,
  live_view: [signing_salt: "K6foGsp3"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :bid, BidPlatform.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  bid: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  bid: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Guardian configuration
config :bid, BidPlatform.Guardian,
  issuer: "bid_platform",
  secret_key: "wIMkehv2tLN8IevSTJCPuc7hbFpF/e8wvV64fOVJli/Px8+ZGt2tEakjKuy7qPEbUKbgMYZ/T0iuvQCHawMnbg=="

# Oban configuration
config :bid, Oban,
  repo: BidPlatform.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron, crontab: [
      # Run ghost sweep every minute
      {"* * * * *", BidPlatform.Workers.AuctionGhostSweepWorker}
    ]}
  ],
  queues: [default: 10, auctions: 50, notifications: 20]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
