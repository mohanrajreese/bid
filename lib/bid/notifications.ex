defmodule BidPlatform.Notifications do
  import Ecto.Query, warn: false
  alias BidPlatform.Repo
  alias BidPlatform.Notifications.Notification
  alias BidPlatform.Notifications.Email
  alias BidPlatform.Mailer

  def notify_outbid(tenant_id, user, auction, new_price) do
    # 1. Create DB record
    {:ok, _} = create_notification(%{
      tenant_id: tenant_id,
      user_id: user.id,
      type: "outbid",
      title: "Outbid!",
      message: "You've been outbid on #{auction.title}. New price: $#{new_price}.",
      metadata: %{auction_id: auction.id}
    })

    # 2. Send email
    Email.outbid_notification(user, auction, new_price) |> Mailer.deliver()

    # 3. Broadcast to user specific channel
    BidPlatformWeb.Endpoint.broadcast("user:#{user.id}", "notification:new", %{type: "outbid"})
  end

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end
end
