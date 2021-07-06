defmodule Zaryn.Mining do
  @moduledoc """
  Handle the ARCH consensus behavior and transaction mining
  """

  alias Zaryn.Crypto

  alias Zaryn.Election

  alias __MODULE__.DistributedWorkflow
  alias __MODULE__.Fee
  alias __MODULE__.PendingTransactionValidation
  alias __MODULE__.StandaloneWorkflow
  alias __MODULE__.WorkerSupervisor
  alias __MODULE__.WorkflowRegistry

  alias Zaryn.P2P
  alias Zaryn.P2P.Node

  alias Zaryn.Replication

  alias Zaryn.SharedSecrets

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.CrossValidationStamp
  alias Zaryn.TransactionChain.Transaction.ValidationStamp

  require Logger

  use Retry

  @doc """
  Start mining process for a given transaction.
  """
  @spec start(
          transaction :: Transaction.t(),
          welcome_node_public_key :: Crypto.key(),
          validation_node_public_keys :: list(Crypto.key())
        ) :: {:ok, pid()}
  def start(tx = %Transaction{}, _welcome_node_public_key, [_ | []]) do
    StandaloneWorkflow.start_link(transaction: tx)
  end

  def start(tx = %Transaction{}, welcome_node_public_key, validation_node_public_keys)
      when is_binary(welcome_node_public_key) and is_list(validation_node_public_keys) do
    DynamicSupervisor.start_child(WorkerSupervisor, {
      DistributedWorkflow,
      transaction: tx,
      welcome_node: P2P.get_node_info!(welcome_node_public_key),
      validation_nodes: Enum.map(validation_node_public_keys, &P2P.get_node_info!/1),
      node_public_key: Crypto.last_node_public_key()
    })
  end

  @doc """
  Return the list of validation nodes for a given transaction and the current validation constraints
  """
  @spec transaction_validation_nodes(Transaction.t(), binary(), DateTime.t()) :: list(Node.t())
  def transaction_validation_nodes(
        tx = %Transaction{address: address, type: type},
        sorting_seed,
        timestamp = %DateTime{}
      )
      when is_binary(sorting_seed) do
    storage_nodes =
      Replication.chain_storage_nodes_with_type(address, type, P2P.authorized_nodes(timestamp))

    constraints = Election.get_validation_constraints()

    Election.validation_nodes(
      tx,
      sorting_seed,
      P2P.authorized_nodes(timestamp),
      storage_nodes,
      constraints
    )
  end

  @doc """
  Determines if the election of validation nodes performed by the welcome node is valid
  """
  @spec valid_election?(Transaction.t(), list(Crypto.key())) :: boolean()
  def valid_election?(tx = %Transaction{validation_stamp: nil}, validation_node_public_keys)
      when is_list(validation_node_public_keys) do
    sorting_seed = Election.validation_nodes_election_seed_sorting(tx, DateTime.utc_now())

    validation_node_public_keys ==
      tx
      |> transaction_validation_nodes(sorting_seed, DateTime.utc_now())
      |> Enum.map(& &1.last_public_key)
  end

  def valid_election?(
        tx = %Transaction{
          validation_stamp: %ValidationStamp{timestamp: timestamp, proof_of_election: poe}
        },
        validation_node_public_keys
      )
      when is_list(validation_node_public_keys) do
    daily_nonce_public_key = SharedSecrets.get_daily_nonce_public_key(timestamp)

    if daily_nonce_public_key == SharedSecrets.genesis_daily_nonce_public_key() do
      # Should happens only during the network bootstrapping
      true
    else
      with true <-
             Election.valid_proof_of_election?(tx, poe, daily_nonce_public_key),
           nodes = [_ | _] <-
             transaction_validation_nodes(tx, poe, timestamp),
           set_of_validation_node_public_keys <- Enum.map(nodes, & &1.last_public_key) do
        Enum.all?(validation_node_public_keys, &(&1 in set_of_validation_node_public_keys))
      else
        _ ->
          false
      end
    end
  end

  @doc """
  Add transaction mining context which built by another cross validation node
  """
  @spec add_mining_context(
          address :: binary(),
          validation_node_public_key :: Crypto.key(),
          previous_storage_nodes_keys :: list(Crypto.key()),
          cross_validation_nodes_view :: bitstring(),
          chain_storage_nodes_view :: bitstring(),
          beacon_storage_nodes_view :: bitstring()
        ) ::
          :ok
  def add_mining_context(
        tx_address,
        validation_node_public_key,
        previous_storage_nodes_keys,
        cross_validation_nodes_view,
        chain_storage_nodes_view,
        beacon_storage_nodes_view
      ) do
    tx_address
    |> get_mining_process!()
    |> DistributedWorkflow.add_mining_context(
      validation_node_public_key,
      P2P.get_nodes_info(previous_storage_nodes_keys),
      cross_validation_nodes_view,
      chain_storage_nodes_view,
      beacon_storage_nodes_view
    )
  end

  @doc """
  Cross validate the validation stamp and the replication tree produced by the coordinator

  If no inconsistencies, the validation stamp is stamped by the the node public key.
  Otherwise the inconsistencies will be signed.
  """
  @spec cross_validate(
          address :: binary(),
          ValidationStamp.t(),
          replication_tree :: %{
            chain: list(bitstring()),
            beacon: list(bitstring()),
            IO: list(bitstring())
          }
        ) :: :ok
  def cross_validate(
        tx_address,
        stamp = %ValidationStamp{},
        replication_tree = %{chain: chain_tree, beacon: beacon_tree, IO: io_tree}
      )
      when is_list(chain_tree) and is_list(beacon_tree) and is_list(io_tree) do
    tx_address
    |> get_mining_process!()
    |> DistributedWorkflow.cross_validate(stamp, replication_tree)
  end

  @doc """
  Add a cross validation stamp to the transaction mining process
  """
  @spec add_cross_validation_stamp(binary(), stamp :: CrossValidationStamp.t()) :: :ok
  def add_cross_validation_stamp(tx_address, stamp = %CrossValidationStamp{}) do
    tx_address
    |> get_mining_process!()
    |> DistributedWorkflow.add_cross_validation_stamp(stamp)
  end

  defp get_mining_process!(tx_address) do
    pid =
      retry_while with: linear_backoff(100, 2) |> expiry(3_000) do
        case Registry.lookup(WorkflowRegistry, tx_address) do
          [{pid, _}] ->
            {:halt, pid}

          _ ->
            {:cont, nil}
        end
      end

    if pid == nil do
      raise "No mining process for the transaction"
    end

    pid
  end

  @doc """
  Validate a pending transaction
  """
  @spec validate_pending_transaction(Transaction.t()) :: :ok | {:error, any()}
  defdelegate validate_pending_transaction(tx), to: PendingTransactionValidation, as: :validate

  @doc """
  Get the transaction fee
  """
  @spec get_transaction_fee(Transaction.t(), float()) :: float()
  defdelegate get_transaction_fee(tx, zaryn_price_in_usd), to: Fee, as: :calculate
end