defmodule BidPlatform.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false
      add :role, :string, null: false, default: "bidder"
      add :is_active, :boolean, null: false, default: true
      add :last_login_at, :utc_datetime
      timestamps()
    end

    create unique_index(:users, [:email, :tenant_id])
    create index(:users, [:tenant_id])
    create index(:users, [:tenant_id, :role])
  end
end
