defmodule Zaryn.Contracts.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.Contracts.Loader
  alias Zaryn.Contracts.TransactionLookup

  alias Zaryn.Utils

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: Zaryn.ContractsSupervisor)
  end

  def init(_args) do
    optional_children = [{TransactionLookup, []}, {Loader, [], []}]

    static_children = [
      {Registry, keys: :unique, name: Zaryn.ContractRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Zaryn.ContractSupervisor}
    ]

    children = static_children ++ Utils.configurable_children(optional_children)
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
