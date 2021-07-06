defmodule Zaryn.BeaconChain.SummaryTimer do
  @moduledoc """
  Handle the scheduling of the beacon summaries creation
  """

  use GenServer

  alias Crontab.CronExpression.Parser, as: CronParser
  alias Crontab.DateChecker
  alias Crontab.Scheduler, as: CronScheduler

  @doc """
  Create a new summary timer
  """
  def start_link(args \\ [], opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Give the next beacon chain slot using the `SlotTimer` interval
  """

  def next_summary(date_from = %DateTime{}) do
    get_interval()
    |> CronParser.parse!(true)
    |> CronScheduler.get_next_run_date!(DateTime.to_naive(date_from))
    |> DateTime.from_naive!("Etc/UTC")
  end

  @doc """
  Returns the list of previous summaries times from the given date
  """
  @spec previous_summary(DateTime.t()) :: DateTime.t()
  def previous_summary(date_from = %DateTime{microsecond: {0, 0}}) do
    get_interval()
    |> CronParser.parse!(true)
    |> CronScheduler.get_previous_run_dates(DateTime.to_naive(date_from))
    |> Enum.at(1)
    |> DateTime.from_naive!("Etc/UTC")
  end

  def previous_summary(date_from = %DateTime{}) do
    get_interval()
    |> CronParser.parse!(true)
    |> CronScheduler.get_previous_run_date!(DateTime.to_naive(date_from))
    |> DateTime.from_naive!("Etc/UTC")
  end

  @doc """
  Return the previous summary time
  """
  @spec previous_summaries(DateTime.t()) :: list(DateTime.t())
  def previous_summaries(date_from = %DateTime{}) do
    get_interval()
    |> CronParser.parse!(true)
    |> CronScheduler.get_previous_run_dates(DateTime.utc_now() |> DateTime.to_naive())
    |> Stream.take_while(fn datetime ->
      datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.compare(date_from) == :gt
    end)
    |> Stream.map(&DateTime.from_naive!(&1, "Etc/UTC"))
    |> Enum.to_list()
  end

  @doc """
  Determine if the given date matches the summary's interval
  """
  @spec match_interval?(DateTime.t()) :: boolean()
  def match_interval?(date = %DateTime{}) do
    get_interval()
    |> CronParser.parse!(true)
    |> DateChecker.matches_date?(DateTime.to_naive(date))
  end

  @doc false
  def init(opts) do
    interval = Keyword.get(opts, :interval)
    :ets.new(:zaryn_summary_timer, [:named_table, :public, read_concurrency: true])
    :ets.insert(:zaryn_summary_timer, {:interval, interval})

    {:ok, %{interval: interval}, :hibernate}
  end

  defp get_interval do
    [{_, interval}] = :ets.lookup(:zaryn_summary_timer, :interval)
    interval
  end

  def handle_cast({:new_conf, conf}, state) do
    case Keyword.get(conf, :interval) do
      nil ->
        {:noreply, state}

      new_interval ->
        :ets.insert(:zaryn_summary_timer, {:interval, new_interval})
        {:noreply, Map.put(state, :interval, new_interval)}
    end
  end

  def config_change(nil), do: :ok

  def config_change(conf) do
    GenServer.cast(__MODULE__, {:new_conf, conf})
  end
end
