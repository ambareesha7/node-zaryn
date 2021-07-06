defmodule Zaryn.Election.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.Election.Constraints
  alias Zaryn.Election.HypergeometricDistribution

  alias Zaryn.Utils

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    optional_children = [
      {Constraints, [], []},
      {HypergeometricDistribution, [], []}
    ]

    children = Utils.configurable_children(optional_children)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
