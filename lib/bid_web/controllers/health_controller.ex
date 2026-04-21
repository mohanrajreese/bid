defmodule BidPlatformWeb.HealthController do
  use BidPlatformWeb, :controller

  @doc """
  Public health check endpoint.
  """
  def check(conn, _params) do
    # Simple check: can we query the DB?
    case Ecto.Adapters.SQL.query(BidPlatform.Repo, "SELECT 1", []) do
      {:ok, _} ->
        json(conn, %{
          status: "healthy",
          timestamp: DateTime.utc_now(),
          services: %{
            database: "up",
            phoenix: "up"
          }
        })

      _ ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          timestamp: DateTime.utc_now(),
          services: %{
            database: "down"
          }
        })
    end
  end
end
