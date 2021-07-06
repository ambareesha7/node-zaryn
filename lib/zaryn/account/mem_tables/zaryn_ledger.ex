defmodule Zaryn.Account.MemTables.ZARYNLedger do
  @moduledoc false

  @ledger_table :zaryn_zaryn_ledger
  @unspent_output_index_table :zaryn_zaryn_unspent_output_index

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Zaryn.TransactionChain.TransactionInput

  use GenServer

  require Logger

  @doc """
  Initialize the ZARYN ledger tables:
  - Main ZARYN ledger as ETS set ({to, from}, amount, spent?)
  - ZARYN Unspent Output Index as ETS bag (to, from)

  ## Examples

      iex> {:ok, _} = ZARYNLedger.start_link()
      iex> { :ets.info(:archethic_zaryn_ledger)[:type], :ets.info(:archethic_zaryn_unspent_output_index)[:type] }
      { :set, :bag }
  """
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_) do
    Logger.info("Initialize InMemory ZARYN Ledger...")

    :ets.new(@ledger_table, [:set, :named_table, :public, read_concurrency: true])

    :ets.new(@unspent_output_index_table, [
      :bag,
      :named_table,
      :public,
      read_concurrency: true
    ])

    {:ok,
     %{
       ledger_table: @ledger_table,
       unspent_outputs_index_table: @unspent_output_index_table
     }}
  end

  @doc """
  Add an unspent output to the ledger for the recipient address

  ## Examples

      iex> {:ok, _pid} = ZARYNLedger.start_link()
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Bob3", amount: 3.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Charlie10", amount: 1.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> { :ets.tab2list(:archethic_zaryn_ledger), :ets.tab2list(:archethic_zaryn_unspent_output_index) }
      {
        [
          {{"@Alice2", "@Bob3"}, 3.0, false, ~U[2021-03-05 13:41:34Z], false},
          {{"@Alice2", "@Charlie10"}, 1.0, false, ~U[2021-03-05 13:41:34Z], false}
       ],
        [
          {"@Alice2", "@Bob3"},
          {"@Alice2", "@Charlie10"}
        ]
      }

  """
  @spec add_unspent_output(binary(), UnspentOutput.t(), DateTime.t()) :: :ok
  def add_unspent_output(
        to,
        %UnspentOutput{from: from, amount: amount, reward?: reward?},
        timestamp = %DateTime{}
      )
      when is_binary(to) and is_float(amount) do
    true = :ets.insert(@ledger_table, {{to, from}, amount, false, timestamp, reward?})
    true = :ets.insert(@unspent_output_index_table, {to, from})
    :ok
  end

  @doc """
  Get the unspent outputs for a given transaction address

  ## Examples

      iex> {:ok, _pid} = ZARYNLedger.start_link()
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Bob3", amount: 3.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Charlie10", amount: 1.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> ZARYNLedger.get_unspent_outputs("@Alice2")
      [
        %UnspentOutput{from: "@Charlie10", amount: 1.0, type: :ZARYN},
        %UnspentOutput{from: "@Bob3", amount: 3.0, type: :ZARYN},
       ]

      iex> {:ok, _pid} = ZARYNLedger.start_link()
      iex> ZARYNLedger.get_unspent_outputs("@Alice2")
      []
  """
  @spec get_unspent_outputs(binary()) :: list(UnspentOutput.t())
  def get_unspent_outputs(address) when is_binary(address) do
    @unspent_output_index_table
    |> :ets.lookup(address)
    |> Enum.reduce([], fn {_, from}, acc ->
      case :ets.lookup(@ledger_table, {address, from}) do
        [{_, amount, false, _, reward?}] ->
          [
            %UnspentOutput{
              from: from,
              amount: amount,
              type: :ZARYN,
              reward?: reward?
            }
            | acc
          ]

        _ ->
          acc
      end
    end)
  end

  @doc """
  Spend all the unspent outputs for the given address

  ## Examples

      iex> {:ok, _pid} = ZARYNLedger.start_link()
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Bob3", amount: 3.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Charlie10", amount: 1.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> :ok = ZARYNLedger.spend_all_unspent_outputs("@Alice2")
      iex> ZARYNLedger.get_unspent_outputs("@Alice2")
      []

  """
  @spec spend_all_unspent_outputs(binary()) :: :ok
  def spend_all_unspent_outputs(address) do
    @unspent_output_index_table
    |> :ets.lookup(address)
    |> Enum.each(&:ets.update_element(@ledger_table, &1, {3, true}))

    :ok
  end

  @doc """
  Retrieve the entire inputs for a given address (spent or unspent)

  ## Examples

      iex> {:ok, _pid} = ZARYNLedger.start_link()
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Bob3", amount: 3.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Charlie10", amount: 1.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> ZARYNLedger.get_inputs("@Alice2")
      [
        %TransactionInput{from: "@Bob3", amount: 3.0, spent?: false, type: :ZARYN, timestamp: ~U[2021-03-05 13:41:34Z]},
        %TransactionInput{from: "@Charlie10", amount: 1.0, spent?: false, type: :ZARYN, timestamp: ~U[2021-03-05 13:41:34Z]}
      ]

      iex> {:ok, _pid} = ZARYNLedger.start_link()
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Bob3", amount: 3.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> :ok = ZARYNLedger.add_unspent_output("@Alice2", %UnspentOutput{from: "@Charlie10", amount: 1.0, type: :ZARYN}, ~U[2021-03-05 13:41:34Z])
      iex> :ok = ZARYNLedger.spend_all_unspent_outputs("@Alice2")
      iex> ZARYNLedger.get_inputs("@Alice2")
      [
        %TransactionInput{from: "@Bob3", amount: 3.0, spent?: true, type: :ZARYN, timestamp: ~U[2021-03-05 13:41:34Z] },
        %TransactionInput{from: "@Charlie10", amount: 1.0, spent?: true, type: :ZARYN, timestamp: ~U[2021-03-05 13:41:34Z]}
      ]
  """
  @spec get_inputs(binary()) :: list(TransactionInput.t())
  def get_inputs(address) when is_binary(address) do
    @unspent_output_index_table
    |> :ets.lookup(address)
    |> Enum.map(fn {_, from} ->
      [{_, amount, spent?, timestamp, reward?}] = :ets.lookup(@ledger_table, {address, from})

      %TransactionInput{
        from: from,
        amount: amount,
        spent?: spent?,
        type: :ZARYN,
        timestamp: timestamp,
        reward?: reward?
      }
    end)
  end
end
