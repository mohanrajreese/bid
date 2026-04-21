defmodule BidPlatform.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  # We specify `down` to allow reversing the migration
  def down do
    Oban.Migration.down(version: 1)
  end
end
