defmodule BidPlatform.Repo.Migrations.EnableRlsPolicies do
  use Ecto.Migration

  def up do
    # Enable RLS on all tenant-scoped tables
    execute "ALTER TABLE users ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE auctions ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE bids ENABLE ROW LEVEL SECURITY;"

    # Create policies to isolate data by tenant_id
    # We use the session variable 'app.current_tenant_id'
    execute """
    CREATE POLICY user_isolation_policy ON users
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
    """

    execute """
    CREATE POLICY auction_isolation_policy ON auctions
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
    """

    execute """
    CREATE POLICY bid_isolation_policy ON bids
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
    """

    # Note: DB superuser and the table owner (usually the app user)
    # can bypass RLS unless 'FORCE ROW LEVEL SECURITY' is used.
    # For extra safety:
    execute "ALTER TABLE users FORCE ROW LEVEL SECURITY;"
    execute "ALTER TABLE auctions FORCE ROW LEVEL SECURITY;"
    execute "ALTER TABLE bids FORCE ROW LEVEL SECURITY;"
  end

  def down do
    execute "ALTER TABLE users DISABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE auctions DISABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE bids DISABLE ROW LEVEL SECURITY;"

    execute "DROP POLICY IF EXISTS user_isolation_policy ON users;"
    execute "DROP POLICY IF EXISTS auction_isolation_policy ON auctions;"
    execute "DROP POLICY IF EXISTS bid_isolation_policy ON bids;"
  end
end
