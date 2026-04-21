defmodule BidPlatform.Repo do
  use Ecto.Repo,
    otp_app: :bid,
    adapter: Ecto.Adapters.Postgres
end
