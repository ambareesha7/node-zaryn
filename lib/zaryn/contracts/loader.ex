defmodule Zaryn.Contracts.Loader do
  @moduledoc false

  alias Zaryn.ContractRegistry
  alias Zaryn.ContractSupervisor

  alias Zaryn.Contracts
  alias Zaryn.Contracts.Contract
  alias Zaryn.Contracts.TransactionLookup
  alias Zaryn.Contracts.Worker

  alias Zaryn.Crypto

  alias Zaryn.TransactionChain
  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp
  alias Zaryn.TransactionChain.TransactionData

  require Logger

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    TransactionChain.list_all([
      :address,
      :previous_public_key,
      data: [:code],
      validation_stamp: [:timestamp]
    ])
    |> Stream.filter(&(&1.data.code != ""))
    |> Stream.each(&load_transaction(&1, true))
    |> Stream.run()

    {:ok, []}
  end

  @doc """
  Load the smart contracts based on transaction involving smart contract code
  """
  @spec load_transaction(Transaction.t()) :: :ok
  def load_transaction(_tx, from_db \\ false)

  def load_transaction(
        tx = %Transaction{
          address: address,
          type: type,
          data: %TransactionData{code: code},
          previous_public_key: previous_public_key
        },
        _from_db
      )
      when code != "" do
    stop_contract(Crypto.hash(previous_public_key))

    case Contracts.parse!(code) do
      # Only load smart contract which are expecting interactions
      %Contract{triggers: triggers = [_ | _]} ->
        triggers = Enum.reject(triggers, &(&1.actions == {:__block__, [], []}))

        # Avoid to load empty smart contract
        if length(triggers) > 0 do
          {:ok, _} =
            DynamicSupervisor.start_child(
              ContractSupervisor,
              {Worker, Contract.from_transaction!(tx)}
            )

          Logger.debug("Smart contract loaded", transaction: "#{type}@#{Base.encode16(address)}")
        end

      _ ->
        :ok
    end
  end

  def load_transaction(
        tx = %Transaction{
          address: tx_address,
          type: tx_type,
          validation_stamp: %ValidationStamp{timestamp: tx_timestamp, recipients: recipients}
        },
        false
      )
      when recipients != [] do
    Enum.each(recipients, fn contract_address ->
      case Worker.execute(contract_address, tx) do
        :ok ->
          TransactionLookup.add_contract_transaction(contract_address, tx_address, tx_timestamp)

          Logger.debug("Transaction towards contract #{Base.encode16(contract_address)} ingested",
            transaction: "#{tx_type}@#{Base.encode16(tx_address)}"
          )

        _ ->
          :ok
      end
    end)
  end

  def load_transaction(
        %Transaction{
          address: address,
          validation_stamp: %ValidationStamp{recipients: recipients, timestamp: timestamp}
        },
        true
      )
      when recipients != [] do
    Enum.each(recipients, &TransactionLookup.add_contract_transaction(&1, address, timestamp))
  end

  def load_transaction(_tx, _), do: :ok

  @doc """
  Termine a contract execution
  """
  @spec stop_contract(binary()) :: :ok
  def stop_contract(address) when is_binary(address) do
    case Registry.lookup(ContractRegistry, address) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(ContractSupervisor, pid)

      _ ->
        :ok
    end
  end
end
