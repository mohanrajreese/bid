defmodule BidPlatformWeb.UserSocket do
  use Phoenix.Socket

  alias BidPlatform.Guardian

  # Channels
  channel "tenant:*:auction:*", BidPlatformWeb.AuctionChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Guardian.resource_from_token(token) do
      {:ok, user, claims} ->
        {:ok, assign(socket, :current_user, user)
             |> assign(:tenant_id, claims["tenant_id"])
             |> assign(:user_role, claims["role"])}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "users_socket:#{socket.assigns.current_user.id}"
end
