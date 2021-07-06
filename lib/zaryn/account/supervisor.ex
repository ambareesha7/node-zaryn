defmodule Zaryn.Account.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.Account.MemTables.NFTLedger
  alias Zaryn.Account.MemTables.ZARYNLedger
  alias Zaryn.Account.MemTablesLoader

  alias Zaryn.Utils

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: Zaryn.AccountSupervisor)
  end

  def init(_args) do
    children = [
      NFTLedger,
      ZARYNLedger,
      MemTablesLoader
    ]

    Supervisor.init(Utils.configurable_children(children), strategy: :one_for_one)
  end
end
