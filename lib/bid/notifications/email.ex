defmodule BidPlatform.Notifications.Email do
  import Swoosh.Email

  def outbid_notification(user, auction, new_price) do
    new()
    |> to(user.email)
    |> from({"BidPlatform", "no-reply@bidapp.sh"})
    |> subject("You've been outbid! — #{auction.title}")
    |> text_body("""
    Hello,

    You've been outbid on #{auction.title}.
    The new current price is $#{new_price}.

    Hurry back to place a new bid!
    """)
  end

  def win_notification(user, auction, amount) do
    new()
    |> to(user.email)
    |> from({"BidPlatform", "no-reply@bidapp.sh"})
    |> subject("Congratulations! You won the auction: #{auction.title}")
    |> html_body("<h1>You Won!</h1><p>Your winning bid was $#{amount}.</p>")
  end
end
