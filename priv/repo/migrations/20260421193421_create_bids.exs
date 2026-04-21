defmodule BidPlatform.Repo.Migrations.CreateBids do
  use Ecto.Migration

  def change do
    create table(:bids, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :auction_id, references(:auctions, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :amount, :decimal, null: false, precision: 15, scale: 2
      add :status, :string, null: false, default: "valid"
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:bids, [:tenant_id])
    create index(:bids, [:auction_id])
    create index(:bids, [:tenant_id, :auction_id])
    create index(:bids, [:auction_id, :inserted_at])
    create index(:bids, [:auction_id, :amount])
  end
end
