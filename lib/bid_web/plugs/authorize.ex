defmodule BidPlatformWeb.Plugs.Authorize do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @doc """
  Ensures the current user has one of the required roles.
  Usage in router: plug BidPlatformWeb.Plugs.Authorize, roles: ["admin"]
  """
  def init(opts), do: opts

  def call(conn, opts) do
    required_roles = Keyword.get(opts, :roles, [])
    current_user = conn.assigns[:current_user]

    cond do
      current_user == nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      current_user.role not in required_roles ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Insufficient permissions",
          required_roles: required_roles,
          current_role: current_user.role
        })
        |> halt()

      true ->
        conn
    end
  end
end
