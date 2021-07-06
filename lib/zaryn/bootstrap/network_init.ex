defmodule Zaryn.Bootstrap.NetworkInit do
  @moduledoc """
  Set up the network by initialize genesis information (i.e storage nonce, coinbase transactions)

  Those functions are only executed by the first node bootstrapping on the network
  """

  alias Zaryn.Bootstrap

  alias Zaryn.Crypto

  alias Zaryn.Election

  alias Zaryn.Mining

  alias Zaryn.P2P.Node

  alias Zaryn.Replication

  alias Zaryn.SharedSecrets

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.CrossValidationStamp
  alias Zaryn.TransactionChain.Transaction.ValidationStamp
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput

  alias Zaryn.TransactionChain.TransactionData
  alias Zaryn.TransactionChain.TransactionData.Ledger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger.Transfer

  require Logger

  @genesis_pools Application.compile_env(:zaryn, __MODULE__)[:genesis_pools]
  @genesis_seed Application.compile_env(:zaryn, __MODULE__)[:genesis_seed]

  @doc """
  Initialize the storage nonce and load it into the keystore
  """
  @spec create_storage_nonce() :: :ok
  def create_storage_nonce do
    Logger.info("Create storage nonce")
    storage_nonce_seed = :crypto.strong_rand_bytes(32)
    {_, pv} = Crypto.generate_deterministic_keypair(storage_nonce_seed)
    Crypto.decrypt_and_set_storage_nonce(Crypto.ec_encrypt(pv, Crypto.last_node_public_key()))
  end

  @doc """
  Create the first node shared secret transaction
  """
  @spec init_node_shared_secrets_chain() :: :ok
  def init_node_shared_secrets_chain do
    Logger.info("Create first node shared secret transaction")
    secret_key = :crypto.strong_rand_bytes(32)
    daily_nonce_seed = :crypto.strong_rand_bytes(32)

    tx =
      SharedSecrets.new_node_shared_secrets_transaction(
        [Crypto.first_node_public_key()],
        daily_nonce_seed,
        secret_key
      )

    tx
    |> self_validation()
    |> self_replication()
  end

  @doc """
  Initializes the genesis wallets for the ZARYN distribution
  """
  @spec init_genesis_wallets() :: :ok
  def init_genesis_wallets do
    network_pool_address = SharedSecrets.get_network_pool_address()
    Logger.info("Create ZARYN distribution genesis transaction")

    tx =
      network_pool_address
      |> genesis_transfers()
      |> create_genesis_transaction()

    genesis_transfers_amount =
      tx
      |> Transaction.get_movements()
      |> Enum.reduce(0.0, &(&2 + &1.amount))

    tx
    |> self_validation([
      %UnspentOutput{
        from: Bootstrap.genesis_unspent_output_address(),
        amount: genesis_transfers_amount,
        type: :ZARYN
      }
    ])
    |> self_replication()
  end

  defp create_genesis_transaction(genesis_transfers) do
    Transaction.new(
      :transfer,
      %TransactionData{
        ledger: %Ledger{
          zaryn: %ZARYNLedger{
            transfers: genesis_transfers
          }
        }
      },
      @genesis_seed,
      0
    )
  end

  defp genesis_transfers(network_pool_address) do
    Enum.map(@genesis_pools, fn {_,
                                 [
                                   public_key: public_key,
                                   amount: amount
                                 ]} ->
      %Transfer{
        to: public_key |> Base.decode16!(case: :mixed) |> Crypto.hash(),
        amount: amount
      }
    end) ++
      [%Transfer{to: network_pool_address, amount: 1.46e9}]
  end

  def self_validation(tx = %Transaction{}, unspent_outputs \\ []) do
    operations =
      %LedgerOperations{
        fee: Mining.get_transaction_fee(tx, 0.07),
        transaction_movements: Transaction.get_movements(tx)
      }
      |> LedgerOperations.from_transaction(tx)
      |> LedgerOperations.distribute_rewards(
        %Node{last_public_key: Crypto.last_node_public_key()},
        [%Node{last_public_key: Crypto.last_node_public_key()}],
        []
      )
      |> LedgerOperations.consume_inputs(tx.address, unspent_outputs)

    validation_stamp =
      %ValidationStamp{
        timestamp: DateTime.utc_now(),
        proof_of_work: Crypto.first_node_public_key(),
        proof_of_election:
          Election.validation_nodes_election_seed_sorting(tx, DateTime.utc_now()),
        proof_of_integrity: tx |> Transaction.serialize() |> Crypto.hash(),
        ledger_operations: operations
      }
      |> ValidationStamp.sign()

    cross_validation_stamp = CrossValidationStamp.sign(%CrossValidationStamp{}, validation_stamp)

    %{
      tx
      | validation_stamp: validation_stamp,
        cross_validation_stamps: [cross_validation_stamp]
    }
  end

  def self_replication(tx = %Transaction{}) do
    Replication.process_transaction(tx, [:chain, :IO, :beacon])
  end
end
