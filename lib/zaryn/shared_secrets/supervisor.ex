defmodule Zaryn.SharedSecrets.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.SharedSecrets.MemTables.NetworkLookup
  alias Zaryn.SharedSecrets.MemTables.OriginKeyLookup
  alias Zaryn.SharedSecrets.MemTablesLoader

  alias Zaryn.SharedSecrets.NodeRenewalScheduler

  alias Zaryn.Utils

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: Zaryn.SharedSecretSupervisor)
  end

  def init(_args) do
    optional_children = [
      NetworkLookup,
      OriginKeyLookup,
      MemTablesLoader,
      {NodeRenewalScheduler, Application.get_env(:zaryn, NodeRenewalScheduler)}
    ]

    children = Utils.configurable_children(optional_children)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
