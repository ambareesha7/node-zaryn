defmodule Zaryn.Account do
  @moduledoc false

  alias __MODULE__.MemTables.NFTLedger
  alias __MODULE__.MemTables.ZARYNLedger
  alias __MODULE__.MemTablesLoader

  alias Zaryn.Crypto

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Zaryn.TransactionChain.TransactionInput

  @type balance :: %{
          zaryn: amount :: float(),
          nft: %{(address :: binary()) => amount :: float()}
        }

  @doc """
  Returns the balance for an address using the unspent outputs
  """
  @spec get_balance(Crypto.versioned_hash()) :: balance()
  def get_balance(address) when is_binary(address) do
    address
    |> get_unspent_outputs()
    |> Enum.reduce(%{zaryn: 0.0, nft: %{}}, fn
      %UnspentOutput{type: :ZARYN, amount: amount}, acc ->
        Map.update!(acc, :zaryn, &(&1 + amount))

      %UnspentOutput{type: {:NFT, nft_address}, amount: amount}, acc ->
        update_in(acc, [:nft, Access.key(nft_address, 0.0)], &(&1 + amount))
    end)
  end

  @doc """
  List all the unspent outputs for a given address
  """
  @spec get_unspent_outputs(binary()) :: list(UnspentOutput.t())
  def get_unspent_outputs(address) do
    ZARYNLedger.get_unspent_outputs(address) ++ NFTLedger.get_unspent_outputs(address)
  end

  @doc """
  List all the inputs for a given transaction (including the spend/unspent inputs)
  """
  @spec get_inputs(binary()) :: list(TransactionInput.t())
  def get_inputs(address) do
    ZARYNLedger.get_inputs(address) ++ NFTLedger.get_inputs(address)
  end

  @doc """
  Load the transaction into the Account context filling the memory tables for ledgers
  """
  @spec load_transaction(Transaction.t()) :: :ok
  defdelegate load_transaction(transaction), to: MemTablesLoader
end
