defmodule BidPlatformWeb.BidController do
  use BidPlatformWeb, :controller

  alias BidPlatform.Bidding

  plug BidPlatformWeb.Plugs.Authorize, [roles: ["bidder", "admin"]]

  def index(conn, %{"auction_id" => auction_id}) do
    tenant_id = conn.assigns.tenant_id
    bids = Bidding.list_bids(tenant_id, auction_id)
    render(conn, :index, bids: bids)
  end

  def create(conn, %{"auction_id" => auction_id, "amount" => amount}) do
    tenant_id = conn.assigns.tenant_id
    user_id = conn.assigns.current_user.id

    # Convert amount to decimal
    case Decimal.cast(amount) do
      {:ok, decimal_amount} ->
        case Bidding.place_bid(tenant_id, auction_id, user_id, decimal_amount) do
          {:ok, result} ->
            conn
            |> put_status(:created)
            |> render(:show, bid: result.bid)

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: format_error(reason)})
        end

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_amount_format"})
    end
  end

  defp format_error(:auction_not_found), do: "auction_not_found"
  defp format_error(:auction_not_active), do: "auction_not_active"
  defp format_error(:self_bidding_not_allowed), do: "self_bidding_not_allowed"
  defp format_error({:insufficient_bid, min}), do: "bid_too_low_min_required_#{min}"
  defp format_error({:bid_too_high, max}), do: "bid_too_high_max_allowed_#{max}"
  defp format_error(:bid_must_be_positive), do: "bid_must_be_positive"
  defp format_error(reason), do: to_string(reason)
end
