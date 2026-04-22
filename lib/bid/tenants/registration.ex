defmodule BidPlatform.Tenants.Registration do
  @moduledoc """
  Handles the atomic registration of a new tenant and its first admin user.
  """

  alias BidPlatform.Repo
  alias BidPlatform.Tenants.Tenant
  alias BidPlatform.Accounts.User
  alias BidPlatform.AuditLogs

  def change_org(tenant, attrs \\ %{}) do
    BidPlatform.Tenants.Tenant.changeset(tenant, attrs)
  end

  @doc """
  Registers a new organization and creates the initial admin user.
  """
  def register_org(org_attrs, user_attrs) do
    IO.inspect(org_attrs, label: "REGISTRATION ORG ATTRS")
    IO.inspect(user_attrs, label: "REGISTRATION USER ATTRS")

    Repo.transaction(fn ->
      with {:ok, tenant} <- create_tenant(org_attrs),
           {:ok, user} <- create_admin_user(tenant, user_attrs),
           {:ok, _log} <- log_registration(tenant, user) do
        %{tenant: tenant, user: user}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp create_tenant(attrs) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  defp create_admin_user(tenant, attrs) do
    # Merge using string keys to maintain consistency with the form parameters
    attrs = Map.merge(attrs, %{"tenant_id" => tenant.id, "role" => "admin"})

    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  defp log_registration(tenant, user) do
    AuditLogs.log(%{
      tenant_id: tenant.id,
      user_id: user.id,
      action: "tenant_registered",
      resource_type: "tenant",
      resource_id: tenant.id,
      changes: %{org_name: tenant.name, subdomain: tenant.subdomain},
      ip_address: "system",
      user_agent: "system"
    })
  end
end
