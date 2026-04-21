defmodule BidPlatformWeb.AuthController do
  use BidPlatformWeb, :controller

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end
end
