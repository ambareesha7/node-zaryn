defmodule Zaryn.Mining.TransactionContext.DataFetcher do
  @moduledoc false

  alias Zaryn.Crypto

  alias Zaryn.P2P
  alias Zaryn.P2P.Message.GetP2PView
  alias Zaryn.P2P.Message.GetTransaction
  alias Zaryn.P2P.Message.GetUnspentOutputs
  alias Zaryn.P2P.Message.NotFound
  alias Zaryn.P2P.Message.P2PView
  alias Zaryn.P2P.Message.UnspentOutputList
  alias Zaryn.P2P.Node

  alias Zaryn.Replication

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput

  @doc """
  Retrieve the previous transaction.

  The request is performed concurrently and the first node to reply is returned
  """
  @spec fetch_previous_transaction(binary(), list(Node.t())) ::
          {:ok, Transaction.t(), Node.t()} | {:error, :not_found} | {:error, :network_issue}
  def fetch_previous_transaction(previous_address, nodes) do
    case P2P.reply_first(nodes, %GetTransaction{address: previous_address}, node_ack?: true) do
      {:ok, tx = %Transaction{}, node} ->
        {:ok, tx, node}

      {:ok, %NotFound{}, _} ->
        {:error, :not_found}

      {:error, :network_issue} ->
        {:error, :network_issue}
    end
  end

  @doc """
  Retrieve the previous unspent outputs.

  An optional confirmation can be processed to confirm
  the unspent output has been really consumed.

  This confirmation request the storage pool of the unspent output
  and asserts the transaction address correspond as a transaction movement or node movement.

  All those requests are performed concurrently and the first nodes to reply are returned
  """
  @spec fetch_unspent_outputs(
          address :: binary(),
          storage_nodes :: list(Node.t()),
          confirmation? :: boolean()
        ) :: {:ok, list(UnspentOutput.t()), list(Node.t())} | {:error, :network_issue}
  def fetch_unspent_outputs(previous_address, nodes, confirmation? \\ true) do
    case P2P.reply_first(nodes, %GetUnspentOutputs{address: previous_address}, node_ack?: true) do
      {:ok, unspent_outputs, node} ->
        {confirmed_utxos, nodes} =
          handle_unspent_outputs(
            {unspent_outputs, node},
            confirmation?,
            previous_address
          )

        {:ok, confirmed_utxos, nodes}

      {:error, :network_issue} ->
        {:error, :network_issue}
    end
  end

  defp handle_unspent_outputs(
         {%UnspentOutputList{unspent_outputs: unspent_outputs = [_ | _]}, node},
         true,
         previous_address
       ) do
    %{unspent_outputs: unspent_outputs, nodes: nodes} =
      confirm_unspent_outputs(unspent_outputs, previous_address)

    {unspent_outputs, P2P.distinct_nodes([node | nodes])}
  end

  defp handle_unspent_outputs({%UnspentOutputList{unspent_outputs: []}, _node}, true, _),
    do: {[], []}

  defp handle_unspent_outputs(
         {%UnspentOutputList{unspent_outputs: unspent_outputs}, node},
         false,
         _
       ),
       do: {unspent_outputs, [node]}

  defp confirm_unspent_outputs(unspent_outputs, tx_address) do
    Task.async_stream(unspent_outputs, &confirm_unspent_output(&1, tx_address),
      on_timeout: :kill_task
    )
    |> Stream.filter(&match?({:ok, {:ok, _, _}}, &1))
    |> Enum.reduce(%{unspent_outputs: [], nodes: []}, fn {:ok, {:ok, unspent_output, node}},
                                                         acc ->
      acc
      |> Map.update!(:unspent_outputs, &[unspent_output | &1])
      |> Map.update!(:nodes, &[node | &1])
    end)
  end

  defp confirm_unspent_output(unspent_output = %UnspentOutput{from: from}, tx_address) do
    storage_nodes = Replication.chain_storage_nodes(from)

    case P2P.reply_first(storage_nodes, %GetTransaction{address: from}, node_ack?: true) do
      {:ok, tx = %Transaction{}, node} ->
        if valid_unspent_output?(tx_address, unspent_output, tx) do
          {:ok, unspent_output, node}
        end

      _ ->
        {:error, :invalid_unspent_output}
    end
  end

  defp valid_unspent_output?(
         tx_address,
         %UnspentOutput{from: from, amount: amount, type: type},
         %Transaction{
           validation_stamp: %ValidationStamp{
             ledger_operations: %LedgerOperations{
               transaction_movements: tx_movements,
               unspent_outputs: unspent_outputs
             }
           }
         }
       ) do
    cond do
      Enum.any?(
        tx_movements,
        &(&1.to == tx_address and &1.amount == amount and &1.type == type)
      ) ->
        true

      Enum.any?(
        unspent_outputs,
        &(&1.from == from and &1.type == type and &1.amount == amount)
      ) ->
        true

      true ->
        false
    end
  end

  defp valid_unspent_output?(_, _, _), do: false

  @doc """
  Request to a set a storage nodes the P2P view of some nodes

  All those requests are performed concurrently and the first nodes to reply are returned
  """
  @spec fetch_p2p_view(node_public_keys :: list(Crypto.key()), storage_nodes :: list(Node.t())) ::
          {:ok, p2p_view :: bitstring(), node_involved :: Node.t()} | {:error, :network_issue}
  def fetch_p2p_view(node_public_keys, storage_nodes) do
    case P2P.reply_first(storage_nodes, %GetP2PView{node_public_keys: node_public_keys},
           node_ack?: true
         ) do
      {:ok, %P2PView{nodes_view: nodes_view}, node} ->
        {:ok, nodes_view, node}

      {:error, :network_issue} ->
        {:error, :network_issue}
    end
  end
end
