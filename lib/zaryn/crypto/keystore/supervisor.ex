defmodule Zaryn.Crypto.KeystoreSupervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.Crypto.NodeKeystore
  alias Zaryn.Crypto.SharedSecretsKeystore

  alias Zaryn.Utils

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    node_keystore_impl = Application.get_env(:zaryn, NodeKeystore)
    node_keystore_conf = Application.get_env(:zaryn, node_keystore_impl)

    children = [
      {NodeKeystore, node_keystore_conf},
      SharedSecretsKeystore
    ]

    Supervisor.init(Utils.configurable_children(children), strategy: :rest_for_one)
  end
end
