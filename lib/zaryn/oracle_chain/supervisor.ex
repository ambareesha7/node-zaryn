defmodule Zaryn.OracleChain.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.OracleChain.MemTable
  alias Zaryn.OracleChain.MemTableLoader
  alias Zaryn.OracleChain.Scheduler

  alias Zaryn.Utils

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(_args) do
    scheduler_conf = Application.get_env(:zaryn, Zaryn.OracleChain.Scheduler)

    children = [
      MemTable,
      MemTableLoader,
      {Scheduler, scheduler_conf}
    ]

    Supervisor.init(Utils.configurable_children(children), strategy: :one_for_one)
  end
end
