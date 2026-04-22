defmodule BidPlatform.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :email, :name, :role, :is_active, :tenant_id]}

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :name, :string
    field :role, :string, default: "bidder"
    field :is_active, :boolean, default: true
    field :last_login_at, :utc_datetime

    belongs_to :tenant, BidPlatform.Tenants.Tenant, type: :binary_id
    has_many :auctions, BidPlatform.Auctions.Auction, foreign_key: :created_by
    has_many :bids, BidPlatform.Bidding.Bid

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :name, :role, :is_active, :tenant_id])
    |> validate_required([:email, :name, :role, :tenant_id])
    |> validate_format(:email, ~r/^[\w.!#$%&'*+\/=?^`{|}~-]+@[\w-]+(?:\.[\w-]+)+$/)
    |> validate_inclusion(:role, ~w[admin bidder super_admin])
    |> unique_constraint([:email, :tenant_id], message: "already registered in this organization")
    |> put_password_hash()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :name])
    |> validate_required([:email, :password, :name])
    |> validate_length(:password, min: 8)
    |> validate_format(:email, ~r/^[\w.!#$%&'*+\/=?^`{|}~-]+@[\w-]+(?:\.[\w-]+)+$/)
    |> unique_constraint([:email, :tenant_id])
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(pw))
  end
  defp put_password_hash(changeset), do: changeset
end
