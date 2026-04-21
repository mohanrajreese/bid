defmodule BidPlatform.Guardian do
  use Guardian, otp_app: :bid

  alias BidPlatform.Accounts

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    # Extracts tenant_id from the authenticated user's JWT
    case Accounts.get_user!(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def build_claims(claims, user, _opts) do
    claims =
      claims
      |> Map.put("tenant_id", user.tenant_id)
      |> Map.put("role", user.role)

    {:ok, claims}
  end
end
