defmodule Zaryn.TransactionChain.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.TransactionChain.MemTables.KOLedger
  alias Zaryn.TransactionChain.MemTables.PendingLedger
  alias Zaryn.TransactionChain.MemTablesLoader

  alias Zaryn.Utils

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: Zaryn.TransactionChainSupervisor)
  end

  def init(_args) do
    optional_children = [PendingLedger, KOLedger, MemTablesLoader]

    children = Utils.configurable_children(optional_children)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
