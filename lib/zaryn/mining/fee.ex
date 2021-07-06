defmodule Zaryn.Mining.Fee do
  @moduledoc """
  Manage the transaction fee calculcation
  """
  alias Zaryn.Bootstrap

  alias Zaryn.Replication

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.TransactionData
  alias Zaryn.TransactionChain.TransactionData.Ledger
  alias Zaryn.TransactionChain.TransactionData.NFTLedger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger

  @min_tx_fee_in_usd 0.1

  @doc """
  Determine the fee to paid for the given transaction

  The fee will differ according to the transaction type and complexity
  Genesis, network and wallet transaction cost nothing.
  """
  @spec calculate(transaction :: Transaction.t(), zaryn_usd_price :: float()) :: fee :: float()
  def calculate(%Transaction{type: :keychain}, _), do: 0.0
  def calculate(%Transaction{type: :access_keychain}, _), do: 0.0

  def calculate(
        tx = %Transaction{
          address: address,
          type: type
        },
        zaryn_price_in_usd
      ) do
    cond do
      address == Bootstrap.genesis_address() ->
        0.0

      true == Transaction.network_type?(type) ->
        0.0

      true ->
        transaction_value = get_transaction_value(tx)
        nb_recipients = get_number_recipients(tx)
        nb_bytes = get_transaction_size(tx)
        nb_storage_nodes = get_number_replicas(tx)

        do_calculate(
          zaryn_price_in_usd,
          transaction_value,
          nb_bytes,
          nb_storage_nodes,
          nb_recipients
        )
        |> Float.floor(6)
    end
  end

  defp get_transaction_value(%Transaction{
         data: %TransactionData{ledger: %Ledger{zaryn: %ZARYNLedger{transfers: zaryn_transfers}}}
       }) do
    Enum.reduce(zaryn_transfers, 0.0, &(&1.amount + &2))
  end

  defp get_transaction_size(tx = %Transaction{}) do
    tx
    |> Transaction.to_pending()
    |> Transaction.serialize()
    |> byte_size()
  end

  defp get_number_recipients(%Transaction{
         data: %TransactionData{
           ledger: %Ledger{
             zaryn: %ZARYNLedger{transfers: zaryn_transfers},
             nft: %NFTLedger{transfers: nft_transfers}
           }
         }
       }) do
    (zaryn_transfers ++ nft_transfers)
    |> Enum.uniq_by(& &1.to)
    |> length()
  end

  defp get_number_replicas(%Transaction{address: address}) do
    address
    |> Replication.chain_storage_nodes()
    |> length()
  end

  defp do_calculate(
         zaryn_price_in_usd,
         transaction_value,
         nb_bytes,
         nb_storage_nodes,
         nb_recipients
       ) do
    # TODO: determine the fee for smart contract execution
    #
    fee_for_value(zaryn_price_in_usd, transaction_value) +
      fee_for_storage(
        zaryn_price_in_usd,
        nb_bytes,
        nb_storage_nodes
      ) +
      cost_per_recipients(nb_recipients, zaryn_price_in_usd)
  end

  # if transaction value less than minimum transaction value => txn fee is minimum txn fee
  defp fee_for_value(zaryn_price_in_usd, transaction_value_in_zaryn)
       when transaction_value_in_zaryn <= @min_tx_fee_in_usd / zaryn_price_in_usd * 1000 do
    get_min_transaction_fee(zaryn_price_in_usd)
  end

  defp fee_for_value(zaryn_price_in_usd, transaction_value_in_zaryn) do
    min_tx_fee = get_min_transaction_fee(zaryn_price_in_usd)
    min_tx_value = min_tx_fee * 1_000
    min_tx_fee * (transaction_value_in_zaryn / min_tx_value)
  end

  defp get_min_transaction_fee(zaryn_price_in_usd) do
    @min_tx_fee_in_usd / zaryn_price_in_usd
  end

  defp fee_for_storage(zaryn_price_in_usd, nb_bytes, nb_storage_nodes) do
    price_per_byte = 1.0e-9 / zaryn_price_in_usd
    price_per_storage_node = price_per_byte * nb_bytes
    price_per_storage_node * nb_storage_nodes
  end

  # Send transaction to a single recipient does not include an additional cost
  defp cost_per_recipients(1, _), do: 0.0

  # Send transaction to multiple recipients (for bulk transfers) will generate an additional cost
  # As more storage pools are required to send the transaction
  defp cost_per_recipients(nb_recipients, zaryn_price_in_usd) do
    nb_recipients * (0.1 / zaryn_price_in_usd)
  end
end
