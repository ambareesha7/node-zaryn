defmodule Zaryn.OracleChain.MemTable do
  @moduledoc false

  use GenServer

  @doc """
  Start a Oracle mem table

  ## Examples

      iex> {:ok, _} = MemTable.start_link()
      iex> :ets.tab2list(:zaryn_oracle)
      []
  """
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_) do
    :ets.new(:zaryn_oracle, [:ordered_set, :named_table, :public, read_concurrency: true])
    {:ok, []}
  end

  @doc """
  Reference some data for an oracle type

  ## Examples

      iex> {:ok, _} = MemTable.start_link()
      iex> MemTable.add_oracle_data("zaryn", %{ "eur" => 0.02 }, ~U[2021-06-04 10:10:00Z])
      iex> :ets.tab2list(:zaryn_oracle)
      [{{ 1622801400, "zaryn"}, %{ "eur" => 0.02 }}]
  """
  @spec add_oracle_data(any(), map(), DateTime.t()) :: :ok
  def add_oracle_data(type, data, date = %DateTime{}) when is_map(data) do
    timestamp =
      date
      |> DateTime.truncate(:second)
      |> DateTime.to_unix()

    true = :ets.insert(:zaryn_oracle, {{timestamp, type}, data})
    :ok
  end

  @doc """
  Get the referenced data for an oracle type for a given date

  ## Examples

      iex> {:ok, _} = MemTable.start_link()
      iex> MemTable.add_oracle_data("zaryn", %{ "eur" => 0.02 }, ~U[2021-06-04 10:00:00Z])
      iex> MemTable.add_oracle_data("zaryn", %{ "eur" => 0.04 }, ~U[2021-06-04 15:00:00Z])
      iex> MemTable.get_oracle_data("zaryn", ~U[2021-06-04 10:10:00Z])
      {:ok, %{ "eur" => 0.02 }}
      iex> MemTable.get_oracle_data("zaryn", ~U[2021-06-04 20:10:40Z])
      {:ok, %{ "eur" => 0.04 }}

  """
  @spec get_oracle_data(any(), DateTime.t()) :: {:ok, map()} | {:error, :not_found}
  def get_oracle_data(type, date = %DateTime{}) do
    timestamp =
      date
      |> DateTime.truncate(:second)
      |> DateTime.to_unix()

    case :ets.lookup(:zaryn_oracle, {timestamp, type}) do
      [] ->
        case :ets.prev(:zaryn_oracle, {timestamp, type}) do
          :"$end_of_table" ->
            {:error, :not_found}

          key ->
            [{_, data}] = :ets.lookup(:zaryn_oracle, key)
            {:ok, data}
        end

      [{_, data}] ->
        {:ok, data}
    end
  end
end
