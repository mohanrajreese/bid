defmodule BidPlatform.Tenants.ProvisioningForm do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :subdomain, :string
    field :admin_name, :string
    field :admin_email, :string
    field :admin_password, :string
  end

  def changeset(form, attrs) do
    form
    |> cast(attrs, [:name, :subdomain, :admin_name, :admin_email, :admin_password])
    |> validate_required([:name, :subdomain, :admin_name, :admin_email, :admin_password])
    |> validate_length(:subdomain, min: 3, max: 20)
    |> validate_format(:subdomain, ~r/^[a-z0-9]+$/, message: "only lowercase letters and numbers")
    |> validate_format(:admin_email, ~r/^[^\s]+@[^\s]+$/, message: "invalid email format")
    |> validate_length(:admin_password, min: 8)
  end
end
