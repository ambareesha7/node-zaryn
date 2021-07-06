defmodule Zaryn.DB.CassandraImpl do
  @moduledoc false

  alias Zaryn.Crypto

  alias Zaryn.DB

  alias __MODULE__.CQL
  alias __MODULE__.Producer
  alias __MODULE__.SchemaMigrator
  alias __MODULE__.Supervisor, as: CassandraSupervisor

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp

  alias Zaryn.Utils

  @behaviour DB

  defdelegate child_spec(arg), to: CassandraSupervisor

  @impl DB
  def migrate do
    SchemaMigrator.run()
  end

  @doc """
  List the transactions
  """
  @impl DB
  @spec list_transactions(list()) :: Enumerable.t()
  def list_transactions(fields \\ []) when is_list(fields) do
    "SELECT #{CQL.list_to_cql(fields)} FROM zaryn.transactions"
    |> Producer.add_query()
    |> Enum.map(&format_result_to_transaction/1)
  end

  @impl DB
  @doc """
  Retrieve a transaction by address and project the requested fields
  """
  @spec get_transaction(binary(), list()) ::
          {:ok, Transaction.t()} | {:error, :transaction_not_exists}
  def get_transaction(address, fields \\ []) when is_binary(address) and is_list(fields) do
    result =
      Producer.add_query(
        "SELECT #{CQL.list_to_cql(fields)} FROM zaryn.transactions WHERE chain_address=? PER PARTITION LIMIT 1",
        [address]
      )

    case Enum.at(result, 0) do
      nil ->
        {:error, :transaction_not_exists}

      tx ->
        {:ok, format_result_to_transaction(tx)}
    end
  end

  @impl DB
  @doc """
  Fetch the transaction chain by address and project the requested fields from the transactions
  """
  @spec get_transaction_chain(binary(), list()) :: Enumerable.t()
  def get_transaction_chain(address, fields \\ []) when is_binary(address) and is_list(fields) do
    1..4
    |> Task.async_stream(fn bucket ->
      "SELECT #{CQL.list_to_cql(fields)} FROM zaryn.transactions WHERE chain_address=? and bucket=?"
      |> Producer.add_query([address, bucket])
      |> Enum.map(&format_result_to_transaction/1)
    end)
    |> Enum.into([], fn {:ok, res} -> res end)
    |> Enum.flat_map(& &1)
  end

  @impl DB
  @doc """
  Store the transaction
  """
  @spec write_transaction(Transaction.t()) :: :ok
  def write_transaction(tx = %Transaction{address: address}) do
    do_write_transaction(tx, address)
  end

  @impl DB
  @doc """
  Store the transaction into the given chain address
  """
  @spec write_transaction(Transaction.t(), binary()) :: :ok
  def write_transaction(tx = %Transaction{}, chain_address) when is_binary(chain_address) do
    do_write_transaction(tx, chain_address)
  end

  defp do_write_transaction(
         tx = %Transaction{},
         chain_address
       ) do
    %{
      "chain_address" => chain_address,
      "bucket" => bucket,
      "timestamp" => timestamp,
      "version" => version,
      "address" => address,
      "type" => type,
      "data" => data,
      "previous_public_key" => previous_public_key,
      "previous_signature" => previous_signature,
      "origin_signature" => origin_signature,
      "validation_stamp" => validation_stamp,
      "cross_validation_stamps" => cross_validation_stamps
    } = encode_transaction_to_parameters(tx, chain_address)

    "INSERT INTO zaryn.transactions (chain_address, bucket, timestamp, version, address, type, data, previous_public_key, previous_signature, origin_signature, validation_stamp, cross_validation_stamps) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    |> Producer.add_query([
      chain_address,
      bucket,
      timestamp,
      version,
      address,
      type,
      data,
      previous_public_key,
      previous_signature,
      origin_signature,
      validation_stamp,
      cross_validation_stamps
    ])

    "INSERT INTO zaryn.transaction_type_lookup(type, address, timestamp) VALUES(?, ?, ?)"
    |> Producer.add_query([type, address, timestamp])

    :ok
  end

  defp encode_transaction_to_parameters(
         tx = %Transaction{validation_stamp: %ValidationStamp{timestamp: timestamp}},
         chain_address
       ) do
    tx
    |> Transaction.to_map()
    |> Utils.stringify_keys()
    |> Map.put("chain_address", chain_address)
    |> Map.put("bucket", bucket_from_date(timestamp))
    |> Map.put("timestamp", timestamp)
  end

  @impl DB
  @doc """
  Store the transactions and store the chain links
  """
  @spec write_transaction_chain(Enumerable.t()) :: :ok
  def write_transaction_chain(chain) do
    %Transaction{
      address: chain_address,
      previous_public_key: chain_public_key
    } = Enum.at(chain, 0)

    chain
    |> Task.async_stream(
      fn tx = %Transaction{
           address: tx_address,
           validation_stamp: %ValidationStamp{timestamp: tx_timestamp},
           previous_public_key: tx_public_key
         } ->
        do_write_transaction(tx, chain_address)

        Producer.add_query(
          "INSERT INTO zaryn.chain_lookup_by_first_address(last_transaction_address, genesis_transaction_address) VALUES (?, ?)",
          [chain_address, tx_address]
        )

        Producer.add_query(
          "INSERT INTO zaryn.chain_lookup_by_first_key(last_key, genesis_key) VALUES (?, ?)",
          [chain_public_key, tx_public_key]
        )

        # Set the last transaction address lookup
        [tx_address, Transaction.previous_address(tx)]
        |> Enum.each(fn address ->
          Producer.add_query(
            "INSERT INTO zaryn.chain_lookup_by_last_address(transaction_address, last_transaction_address, timestamp) VALUES(?, ?, ?)",
            [
              address,
              chain_address,
              tx_timestamp
            ]
          )
        end)
      end,
      ordered: false
    )
    |> Stream.run()

    :ok
  end

  defp bucket_from_date(%DateTime{month: month}) do
    div(month + 2, 3)
  end

  defp format_result_to_transaction(res) do
    res
    |> Map.drop(["bucket", "chain_address", "timestamp"])
    |> Utils.atomize_keys(true)
    |> Transaction.from_map()
  end

  @doc """
  Reference a last address from a previous address
  """
  @impl DB
  @spec add_last_transaction_address(binary(), binary(), DateTime.t()) :: :ok
  def add_last_transaction_address(tx_address, last_address, timestamp = %DateTime{}) do
    Producer.add_query(
      "INSERT INTO zaryn.chain_lookup_by_last_address(transaction_address, last_transaction_address, timestamp) VALUES(?, ?, ?)",
      [tx_address, last_address, timestamp]
    )

    :ok
  end

  @doc """
  List the last transaction lookups
  """
  @impl DB
  @spec list_last_transaction_addresses() :: Enumerable.t()
  def list_last_transaction_addresses do
    "SELECT * FROM zaryn.chain_lookup_by_last_address PER PARTITION LIMIT 1"
    |> Producer.add_query()
    |> Enum.map(fn %{
                     "transaction_address" => address,
                     "last_transaction_address" => last_address,
                     "timestamp" => timestamp
                   } ->
      {address, last_address, timestamp}
    end)
  end

  @impl DB
  @spec chain_size(binary()) :: non_neg_integer()
  def chain_size(address) do
    "SELECT COUNT(*) as size FROM zaryn.transactions WHERE chain_address=?"
    |> Producer.add_query([address])
    |> Enum.at(0, %{})
    |> Map.get("size", 0)
  end

  @impl DB
  @spec list_transactions_by_type(type :: Transaction.transaction_type(), fields :: list()) ::
          Enumerable.t()
  def list_transactions_by_type(type, fields \\ []) do
    "SELECT address FROM zaryn.transaction_type_lookup WHERE type=?"
    |> Producer.add_query([Atom.to_string(type)])
    |> Task.async_stream(fn %{"address" => address} ->
      "SELECT #{CQL.list_to_cql(fields)} FROM zaryn.transactions WHERE chain_address=?"
      |> Producer.add_query([address])
      |> Enum.at(0)
      |> format_result_to_transaction()
    end)
    |> Enum.into([], fn {:ok, res} -> res end)
  end

  @impl DB
  @spec count_transactions_by_type(type :: Transaction.transaction_type()) :: non_neg_integer()
  def count_transactions_by_type(type) do
    "SELECT COUNT(address) as nb FROM zaryn.transaction_type_lookup WHERE type=?"
    |> Producer.add_query([Atom.to_string(type)])
    |> Enum.at(0, %{})
    |> Map.get("nb", 0)
  end

  @doc """
  Get the last transaction address of a chain
  """
  @impl DB
  @spec get_last_chain_address(binary()) :: binary()
  def get_last_chain_address(address) do
    "SELECT last_transaction_address FROM zaryn.chain_lookup_by_last_address WHERE transaction_address = ?"
    |> Producer.add_query([address])
    |> Enum.at(0, %{})
    |> Map.get("last_transaction_address", address)
  end

  @doc """
  Get the last transaction address of a chain before a given certain datetime
  """
  @impl DB
  @spec get_last_chain_address(binary(), DateTime.t()) :: binary()
  def get_last_chain_address(address, datetime = %DateTime{}) do
    "SELECT last_transaction_address FROM zaryn.chain_lookup_by_last_address WHERE transaction_address = ? and timestamp <= ?"
    |> Producer.add_query([address, datetime])
    |> Enum.at(0, %{})
    |> Map.get("last_transaction_address", address)
  end

  @doc """
  Get the first transaction address for a chain
  """
  @impl DB
  @spec get_first_chain_address(binary()) :: binary()
  def get_first_chain_address(address) when is_binary(address) do
    "SELECT genesis_transaction_address FROM zaryn.chain_lookup_by_first_address WHERE last_transaction_address=?"
    |> Producer.add_query([address])
    |> Enum.at(0, %{})
    |> Map.get("genesis_transaction_address", address)
  end

  @doc """
  Get the first public key of of transaction chain
  """
  @impl DB
  @spec get_first_public_key(Crypto.key()) :: Crypto.key()
  def get_first_public_key(previous_public_key) when is_binary(previous_public_key) do
    "SELECT genesis_key FROM zaryn.chain_lookup_by_first_key WHERE last_key=?"
    |> Producer.add_query([previous_public_key])
    |> Enum.at(0, %{})
    |> Map.get("genesis_key", previous_public_key)
  end

  @doc """
  Return the latest TPS record
  """
  @impl DB
  @spec get_latest_tps :: float()
  def get_latest_tps do
    "SELECT tps FROM zaryn.network_stats_by_date"
    |> Producer.add_query()
    |> Enum.at(0, %{})
    |> Map.get("tps", 0.0)
  end

  @doc """
  Returns the number of transactions
  """
  @impl DB
  @spec get_nb_transactions() :: non_neg_integer()
  def get_nb_transactions do
    "SELECT nb_transactions FROM zaryn.network_stats_by_date"
    |> Producer.add_query()
    |> Enum.reduce(0, fn %{"nb_transactions" => nb_transactions}, acc -> nb_transactions + acc end)
  end

  @doc """
  Register a new TPS for the given date
  """
  @impl DB
  @spec register_tps(DateTime.t(), float(), non_neg_integer()) :: :ok
  def register_tps(date = %DateTime{}, tps, nb_transactions)
      when is_float(tps) and tps >= 0.0 and is_integer(nb_transactions) and nb_transactions >= 0 do
    Producer.add_query(
      "INSERT INTO zaryn.network_stats_by_date (date, tps, nb_transactions) VALUES (?, ?, ?)",
      [date, tps, nb_transactions]
    )

    :ok
  end

  @doc """
  Determines if the transaction address exists
  """
  @impl DB
  @spec transaction_exists?(binary()) :: boolean()
  def transaction_exists?(address) when is_binary(address) do
    count =
      "SELECT COUNT(address) as count FROM zaryn.transactions WHERE chain_address=?"
      |> Producer.add_query([address])
      |> Enum.at(0, %{})
      |> Map.get("count", 0)

    count > 0
  end
end
