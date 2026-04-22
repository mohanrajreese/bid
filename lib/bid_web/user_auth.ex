defmodule BidPlatformWeb.UserAuth do
  use BidPlatformWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller

  alias BidPlatform.Accounts

  @doc """
  Logs the user in.
  It renews the session ID and clears the whole session to avoid fixation attacks.
  It also sets a `user_token` for later verification.
  """
  def log_in_user(conn, user, _params \\ %{}) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> redirect(to: signed_in_path(user))
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.
  """
  def log_out_user(conn) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user!(user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Used for routes that require authentication.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc """
  LiveView on_mount hook to fetch the current user.
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/login")}
    end
  end

  def on_mount(:ensure_super_admin, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user && socket.assigns.current_user.role == "super_admin" do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Unauthorized access.")
       |> Phoenix.LiveView.redirect(to: ~p"/")}
    end
  end

  defp mount_current_user(session, socket) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_id = session["user_id"] do
        Accounts.get_user!(user_id)
      end
    end)
  end

  def signed_in_path(user) do
    case user.role do
      "super_admin" -> ~p"/super-admin"
      "admin" -> ~p"/admin"
      _ -> ~p"/auctions"
    end
  end
end
