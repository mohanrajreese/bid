defmodule BidPlatform.Repo.Migrations.CreateProxyBids do
  use Ecto.Migration

  def change do
    create table(:proxy_bids, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :auction_id, references(:auctions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :max_amount, :decimal, null: false, precision: 15, scale: 2
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create index(:proxy_bids, [:tenant_id])
    create index(:proxy_bids, [:auction_id])
    create unique_index(:proxy_bids, [:auction_id, :user_id], where: "is_active = true")
  end
end
