defmodule BidPlatformWeb.AuthController do
  use BidPlatformWeb, :controller

  alias BidPlatform.Accounts
  alias BidPlatformWeb.UserAuth

  def create(conn, %{"email" => email, "password" => password}) do
    if user = Accounts.get_user_by_email(email) do
      # In a real app, verify password hash here
      UserAuth.log_in_user(conn, user)
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    UserAuth.log_out_user(conn)
  end
end
