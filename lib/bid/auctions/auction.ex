defmodule BidPlatform.Auctions.Auction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [
    :id, :title, :description, :type, :start_price, :current_price,
    :min_increment, :reserve_price, :start_time, :end_time, :status,
    :winner_id, :winning_bid_id, :bid_count, :tenant_id, :created_by
  ]}

  @valid_types ~w[english reverse]
  @valid_statuses ~w[draft scheduled active closed force_closed no_bids reserve_not_met cancelled]

  schema "auctions" do
    field :title, :string
    field :description, :string
    field :type, :string
    field :start_price, :decimal
    field :current_price, :decimal
    field :min_increment, :decimal
    field :reserve_price, :decimal
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :original_end_time, :utc_datetime
    field :status, :string, default: "draft"
    field :winning_bid_id, :binary_id
    field :bid_count, :integer, default: 0
    field :settings, :map, default: %{}

    belongs_to :tenant, BidPlatform.Tenants.Tenant, type: :binary_id
    belongs_to :creator, BidPlatform.Accounts.User, type: :binary_id, foreign_key: :created_by
    belongs_to :winner, BidPlatform.Accounts.User, type: :binary_id, foreign_key: :winner_id

    # has_many :bids, BidPlatform.Bidding.Bid

    timestamps()
  end

  def changeset(auction, attrs) do
    auction
    |> cast(attrs, [
      :title, :description, :type, :start_price, :current_price,
      :min_increment, :reserve_price, :start_time, :end_time,
      :status, :tenant_id, :created_by, :settings
    ])
    |> validate_required([:title, :type, :start_price, :min_increment, :end_time, :tenant_id, :created_by])
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:start_price, greater_than: 0)
    |> validate_number(:min_increment, greater_than: 0)
    |> validate_end_time_after_now()
    |> validate_reserve_price()
    |> set_current_price()
    |> set_original_end_time()
  end

  defp validate_end_time_after_now(changeset) do
    validate_change(changeset, :end_time, fn :end_time, end_time ->
      if DateTime.compare(end_time, DateTime.utc_now()) == :gt do
        []
      else
        [end_time: "must be in the future"]
      end
    end)
  end

  defp validate_reserve_price(changeset) do
    type = get_field(changeset, :type)
    reserve = get_change(changeset, :reserve_price)

    cond do
      type == "reverse" && reserve != nil ->
        add_error(changeset, :reserve_price, "not allowed for reverse auctions")
      type == "english" && reserve != nil ->
        start = get_field(changeset, :start_price)
        if Decimal.compare(reserve, start) == :lt do
          add_error(changeset, :reserve_price, "must be greater than or equal to start price")
        else
          changeset
        end
      true ->
        changeset
    end
  end

  defp set_current_price(changeset) do
    if get_field(changeset, :current_price) == nil do
      put_change(changeset, :current_price, get_field(changeset, :start_price))
    else
      changeset
    end
  end

  defp set_original_end_time(changeset) do
    if get_field(changeset, :original_end_time) == nil do
      put_change(changeset, :original_end_time, get_field(changeset, :end_time))
    else
      changeset
    end
  end
end
