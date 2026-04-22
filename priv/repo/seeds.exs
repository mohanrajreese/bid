alias BidPlatform.Repo
alias BidPlatform.Tenants.Tenant
alias BidPlatform.Accounts.User

Repo.transaction(fn ->
  # 1. Create a "Platform" tenant if it doesn't exist
  tenant = case Repo.get_by(Tenant, subdomain: "platform") do
    nil ->
      %Tenant{}
      |> Tenant.changeset(%{
        name: "BidPlatform HQ",
        subdomain: "platform",
        plan: "enterprise"
      })
      |> Repo.insert!()
    tenant -> tenant
  end

  # 2. Create Super Admin user
  case Repo.get_by(User, email: "superadmin@bidplatform.com") do
    nil ->
      %User{}
      |> User.changeset(%{
        email: "superadmin@bidplatform.com",
        name: "Global Admin",
        password: "password1234",
        role: "super_admin",
        tenant_id: tenant.id
      })
      |> Repo.insert!()
      IO.puts ">>> Super Admin created: superadmin@bidplatform.com / password1234"
    _user ->
      IO.puts ">>> Super Admin already exists."
  end
end)
