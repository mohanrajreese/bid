defmodule BidPlatformWeb.AdminLive.AuctionForm do
  use BidPlatformWeb, :live_component

  alias BidPlatform.Auctions
  alias BidPlatform.Auctions.Auction

  @impl true
  def update(%{auction: auction} = assigns, socket) do
    changeset = Auctions.change_auction(auction)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"auction" => auction_params}, socket) do
    changeset =
      socket.assigns.auction
      |> Auctions.change_auction(auction_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"auction" => auction_params}, socket) do
    save_auction(socket, socket.assigns.action, auction_params)
  end

  defp save_auction(socket, :edit, auction_params) do
    case Auctions.update_auction(socket.assigns.auction, auction_params) do
      {:ok, auction} ->
        notify_parent({:saved, auction})
        {:noreply,
         socket
         |> put_flash(:info, "Auction updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_auction(socket, :new, auction_params) do
    case Auctions.create_auction(Map.put(auction_params, "tenant_id", socket.assigns.tenant_id)) do
      {:ok, auction} ->
        notify_parent({:saved, auction})
        {:noreply,
         socket
         |> put_flash(:info, "Auction created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  @impl true
  def render(assigns) do
    ~H"""
    <div class="glass p-8 rounded-3xl">
      <h2 class="text-2xl font-black text-white text-glow mb-6">{@title}</h2>

      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save" class="space-y-4">
        <div>
          <label class="text-white/50 text-xs font-bold pl-1">TITLE</label>
          <.input field={@form[:title]} placeholder="Masterpiece Painting" class="glass-dark border-white/10 text-white" />
        </div>

        <div>
          <label class="text-white/50 text-xs font-bold pl-1">DESCRIPTION</label>
          <.input field={@form[:description]} type="textarea" placeholder="Describe the item..." class="glass-dark border-white/10 text-white" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="text-white/50 text-xs font-bold pl-1">TYPE</label>
            <.input field={@form[:type]} type="select" options={["english", "reverse"]} class="glass-dark border-white/10 text-white" />
          </div>
          <div>
            <label class="text-white/50 text-xs font-bold pl-1">
              <%= if @form[:type].value == "reverse", do: "CEILING PRICE (MAX)", else: "FLOOR PRICE (START)" %>
            </label>
            <.input field={@form[:start_price]} type="number" step="0.01" class="glass-dark border-white/10 text-white" />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="text-white/50 text-xs font-bold pl-1">
               <%= if @form[:type].value == "reverse", do: "MIN DECREMENT", else: "MIN INCREMENT" %>
            </label>
            <.input field={@form[:min_increment]} type="number" step="0.01" class="glass-dark border-white/10 text-white" />
          </div>
          <div>
            <label class="text-white/50 text-xs font-bold pl-1">END TIME</label>
            <.input field={@form[:end_time]} type="datetime-local" class="glass-dark border-white/10 text-white" />
          </div>
        </div>

        <div class="pt-6">
          <button type="submit" phx-disable-with="Saving..." class="w-full btn-premium py-4">
            Save Auction
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
