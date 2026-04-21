defmodule BidPlatformWeb.PageController do
  use BidPlatformWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
