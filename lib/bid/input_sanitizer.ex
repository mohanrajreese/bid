defmodule BidPlatform.InputSanitizer do
  @moduledoc """
  Centralized input sanitization for strings and numeric values.
  """

  def sanitize_string(nil), do: nil
  def sanitize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(<<0>>, "")        # Remove null bytes
    |> String.slice(0, 10_000)          # Hard limit on length
  end

  def sanitize_amount(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> validate_decimal_range(decimal)
      _ -> {:error, "Invalid numeric format"}
    end
  end
  def sanitize_amount(value) when is_number(value) do
    value |> to_string() |> sanitize_amount()
  end
  def sanitize_amount(%Decimal{} = value), do: validate_decimal_range(value)
  def sanitize_amount(_), do: {:error, "Invalid amount type"}

  defp validate_decimal_range(decimal) do
    max_amount = Decimal.new("999999999999.99")

    cond do
      Decimal.compare(decimal, Decimal.new(0)) != :gt ->
        {:error, "Amount must be positive"}
      Decimal.compare(decimal, max_amount) == :gt ->
        {:error, "Amount exceeds maximum allowed value"}
      true ->
        {:ok, decimal}
    end
  end
end
