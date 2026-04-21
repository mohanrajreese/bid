defmodule BidPlatformWeb.Plugs.Auth do
  import Plug.Conn
  alias BidPlatform.Guardian

  def init(opts), do: opts

  def call(conn, _opts) do
    # 1. Look for Authorization header
    # 2. Verify JWT
    # 3. Load user into assigns
    # 4. Load tenant_id into assigns (isolation enforcement)

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Guardian.resource_from_token(token) do
          {:ok, user, claims} ->
            conn
            |> assign(:current_user, user)
            |> assign(:tenant_id, claims["tenant_id"])
            |> assign(:user_role, claims["role"])

          {:error, _reason} ->
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
    |> halt()
  end
end
