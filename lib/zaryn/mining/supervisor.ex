defmodule Zaryn.Mining.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: Zaryn.MiningSupervisor)
  end

  def init(_opts) do
    children = [
      {Registry,
       name: Zaryn.Mining.WorkflowRegistry, keys: :unique, partitions: System.schedulers_online()},
      {DynamicSupervisor, strategy: :one_for_one, name: Zaryn.Mining.WorkerSupervisor}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
