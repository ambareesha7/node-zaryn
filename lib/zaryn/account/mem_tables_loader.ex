defmodule Zaryn.Account.MemTablesLoader do
  @moduledoc false

  use GenServer

  alias Zaryn.Account.MemTables.NFTLedger
  alias Zaryn.Account.MemTables.ZARYNLedger

  alias Zaryn.Crypto

  alias Zaryn.P2P
  alias Zaryn.P2P.Node

  alias Zaryn.TransactionChain
  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.NodeMovement

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.TransactionMovement

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput

  require Logger

  @query_fields [
    :address,
    :type,
    :previous_public_key,
    validation_stamp: [
      :timestamp,
      ledger_operations: [:node_movements, :unspent_outputs, :transaction_movements]
    ]
  ]

  @excluded_types [
    :node,
    :beacon,
    :beacon_summary,
    :oracle,
    :oracle_summary,
    :node_shared_secrets,
    :origin_shared_secrets
  ]

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    TransactionChain.list_all(@query_fields)
    |> Stream.reject(&(&1.type in @excluded_types))
    |> Stream.each(&load_transaction/1)
    |> Stream.run()

    {:ok, []}
  end

  @doc """
  Load the transaction into the memory tables
  """
  @spec load_transaction(Transaction.t()) :: :ok
  def load_transaction(%Transaction{
        address: address,
        type: type,
        previous_public_key: previous_public_key,
        validation_stamp: %ValidationStamp{
          timestamp: timestamp,
          ledger_operations: %LedgerOperations{
            unspent_outputs: unspent_outputs,
            node_movements: node_movements,
            transaction_movements: transaction_movements
          }
        }
      }) do
    previous_address = Crypto.hash(previous_public_key)

    ZARYNLedger.spend_all_unspent_outputs(previous_address)
    NFTLedger.spend_all_unspent_outputs(previous_address)

    :ok = set_transaction_movements(address, transaction_movements, timestamp)
    :ok = set_unspent_outputs(address, unspent_outputs, timestamp)
    :ok = set_node_rewards(address, node_movements, timestamp)

    Logger.debug("Loaded into in memory account tables",
      transaction: "#{type}@#{Base.encode16(address)}"
    )
  end

  defp set_transaction_movements(address, transaction_movements, timestamp) do
    Enum.each(transaction_movements, fn
      %TransactionMovement{to: to, amount: amount, type: :ZARYN} ->
        ZARYNLedger.add_unspent_output(
          to,
          %UnspentOutput{amount: amount, from: address, type: :ZARYN},
          timestamp
        )

      %TransactionMovement{to: to, amount: amount, type: {:NFT, nft_address}} ->
        NFTLedger.add_unspent_output(
          to,
          %UnspentOutput{
            amount: amount,
            from: address,
            type: {:NFT, nft_address}
          },
          timestamp
        )
    end)
  end

  defp set_unspent_outputs(address, unspent_outputs, timestamp) do
    unspent_outputs
    |> Enum.filter(&(&1.amount > 0.0))
    |> Enum.each(fn
      unspent_output = %UnspentOutput{type: :ZARYN} ->
        ZARYNLedger.add_unspent_output(address, unspent_output, timestamp)

      unspent_output = %UnspentOutput{type: {:NFT, _nft_address}} ->
        NFTLedger.add_unspent_output(address, unspent_output, timestamp)
    end)
  end

  defp set_node_rewards(address, node_movements, timestamp) do
    node_movements
    |> Enum.filter(&(&1.amount > 0.0))
    |> Enum.each(fn %NodeMovement{to: to, amount: amount} ->
      %Node{reward_address: reward_address} = P2P.get_node_info!(to)

      ZARYNLedger.add_unspent_output(
        reward_address,
        %UnspentOutput{amount: amount, from: address, type: :ZARYN, reward?: true},
        timestamp
      )
    end)
  end
end
