defmodule ZarynWeb.GraphQLSchema.Resolver do
  @moduledoc false

  alias Zaryn

  alias Zaryn.Crypto

  alias Zaryn.TransactionChain
  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.TransactionInput

  @limit_page 10

  def get_balance(address) do
    %{zaryn: zaryn, nft: nft_balances} = Zaryn.get_balance(address)

    %{
      zaryn: zaryn,
      nft:
        nft_balances
        |> Enum.map(fn {address, amount} -> %{address: address, amount: amount} end)
        |> Enum.sort_by(& &1.amount)
    }
  end

  def get_inputs(address) do
    inputs = Zaryn.get_transaction_inputs(address)
    Enum.map(inputs, &TransactionInput.to_map/1)
  end

  def shared_secrets do
    %{
      storage_nonce_public_key: Crypto.storage_nonce_public_key()
    }
  end

  def paginate_chain(address, page) do
    address
    |> Zaryn.get_transaction_chain()
    |> paginate_transactions(page)
  end

  def paginate_local_transactions(page) do
    paginate_transactions(TransactionChain.list_all(), page)
  end

  defp paginate_transactions(transactions, page) do
    start_pagination = (page - 1) * @limit_page
    end_pagination = @limit_page

    transactions
    |> Enum.slice(start_pagination, end_pagination)
    |> Enum.map(&Transaction.to_map/1)
  end

  def get_last_transaction(address) do
    case Zaryn.get_last_transaction(address) do
      {:ok, tx} ->
        {:ok, Transaction.to_map(tx)}

      {:error, :transaction_not_exists} = e ->
        e
    end
  end

  def get_transaction(address) do
    case Zaryn.search_transaction(address) do
      {:ok, tx} ->
        {:ok, Transaction.to_map(tx)}

      {:error, :transaction_not_exists} = e ->
        e
    end
  end

  def get_chain_length(address) do
    Zaryn.get_transaction_chain_length(address)
  end
end
