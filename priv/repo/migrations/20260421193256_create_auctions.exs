defmodule BidPlatform.Repo.Migrations.CreateAuctions do
  use Ecto.Migration

  def change do
    create table(:auctions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :created_by, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :title, :string, null: false
      add :description, :text
      add :type, :string, null: false
      add :start_price, :decimal, null: false, precision: 15, scale: 2
      add :current_price, :decimal, null: false, precision: 15, scale: 2
      add :min_increment, :decimal, null: false, precision: 15, scale: 2
      add :reserve_price, :decimal, precision: 15, scale: 2
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime, null: false
      add :original_end_time, :utc_datetime
      add :status, :string, null: false, default: "draft"
      add :winner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :winning_bid_id, :binary_id
      add :bid_count, :integer, null: false, default: 0
      add :settings, :map, default: %{}
      timestamps()
    end

    create index(:auctions, [:tenant_id])
    create index(:auctions, [:tenant_id, :status])
    create index(:auctions, [:tenant_id, :type])
    create index(:auctions, [:status, :end_time])
    create index(:auctions, [:end_time])
  end
end
