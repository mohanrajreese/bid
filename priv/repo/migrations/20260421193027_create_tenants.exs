defmodule BidPlatform.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :subdomain, :string, null: false
      add :slug, :string
      add :plan, :string, null: false, default: "free"
      add :is_active, :boolean, null: false, default: true
      add :settings, :map, default: %{}
      timestamps()
    end

    create unique_index(:tenants, [:subdomain])
    create index(:tenants, [:is_active])
  end
end
