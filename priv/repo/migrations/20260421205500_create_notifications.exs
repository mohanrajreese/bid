defmodule BidPlatform.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :title, :string
      add :message, :text
      add :read_at, :utc_datetime
      add :metadata, :map

      timestamps()
    end

    create index(:notifications, [:tenant_id])
    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read_at])
  end
end
