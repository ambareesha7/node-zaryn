defmodule Zaryn.Reward.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.Reward.NetworkPoolScheduler

  alias Zaryn.Utils

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: Zaryn.RewardSupervisor)
  end

  def init(_) do
    children = [
      {NetworkPoolScheduler, Application.get_env(:zaryn, NetworkPoolScheduler)}
    ]

    Supervisor.init(Utils.configurable_children(children), strategy: :one_for_one)
  end
end
