defmodule Zaryn.Governance.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.Governance.Code.CICD
  alias Zaryn.Governance.Pools.MemTable
  alias Zaryn.Governance.Pools.MemTableLoader

  alias Zaryn.Utils

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  def init(_args) do
    children = [
      CICD,
      MemTable,
      MemTableLoader
    ]

    Supervisor.init(Utils.configurable_children(children), strategy: :rest_for_one)
  end
end
