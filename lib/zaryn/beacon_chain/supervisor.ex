defmodule Zaryn.BeaconChain.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.BeaconChain
  alias Zaryn.BeaconChain.SlotTimer
  alias Zaryn.BeaconChain.Subset
  alias Zaryn.BeaconChain.SummaryTimer

  alias Zaryn.Utils

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    BeaconChain.init_subsets()
    subsets = BeaconChain.list_subsets()

    optional_children = [
      {SlotTimer, Application.get_env(:zaryn, SlotTimer), []},
      {SummaryTimer, Application.get_env(:zaryn, SummaryTimer), []}
      | Enum.map(
          subsets,
          &{Subset, [subset: &1], [id: &1]}
        )
    ]

    static_children = [
      {Registry,
       keys: :unique, name: BeaconChain.SubsetRegistry, partitions: System.schedulers_online()}
    ]

    children = static_children ++ Utils.configurable_children(optional_children)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
