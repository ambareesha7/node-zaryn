defmodule Zaryn.Contracts.Contract.Constants do
  @moduledoc """
  Represents the smart contract constants and bindings
  """

  defstruct [:contract, :transaction]

  @type t :: %__MODULE__{
          contract: map(),
          transaction: map() | nil
        }

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.TransactionData
  alias Zaryn.TransactionChain.TransactionData.Keys
  alias Zaryn.TransactionChain.TransactionData.Ledger
  alias Zaryn.TransactionChain.TransactionData.NFTLedger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger

  @doc """
  Extract constants from a transaction into a map
  """
  @spec from_transaction(Transaction.t()) :: map()
  def from_transaction(%Transaction{
        address: address,
        type: type,
        previous_public_key: previous_public_key,
        data: %TransactionData{
          content: content,
          code: code,
          keys: %Keys{
            authorized_keys: authorized_keys,
            secret: secret
          },
          ledger: %Ledger{
            zaryn: %ZARYNLedger{
              transfers: zaryn_transfers
            },
            nft: %NFTLedger{
              transfers: nft_transfers
            }
          },
          recipients: recipients
        }
      }) do
    %{
      "address" => address,
      "type" => Atom.to_string(type),
      "content" => content,
      "code" => code,
      "authorized_keys" => Map.keys(authorized_keys),
      "secret" => secret,
      "previous_public_key" => previous_public_key,
      "recipients" => recipients,
      "zaryn_transfers" =>
        zaryn_transfers
        |> Enum.map(fn %ZARYNLedger.Transfer{to: to, amount: amount} -> {to, amount} end)
        |> Enum.into(%{}),
      "nft_transfers" =>
        nft_transfers
        |> Enum.map(fn %NFTLedger.Transfer{
                         to: to,
                         amount: amount,
                         nft: nft_address
                       } ->
          {to, %{"amount" => amount, "nft" => nft_address}}
        end)
        |> Enum.into(%{})
    }
  end
end
