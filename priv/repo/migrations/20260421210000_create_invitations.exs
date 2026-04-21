defmodule BidPlatform.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :email, :string, null: false
      add :token, :string, null: false
      add :role, :string, default: "bidder"
      add :accepted_at, :utc_datetime
      add :expired_at, :utc_datetime

      timestamps()
    end

    create index(:invitations, [:tenant_id])
    create unique_index(:invitations, [:token])
    create unique_index(:invitations, [:tenant_id, :email], where: "accepted_at IS NULL")
  end
end
