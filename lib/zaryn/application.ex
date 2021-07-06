defmodule Zaryn.Application do
  @moduledoc false

  use Application

  alias Zaryn.Account.Supervisor, as: AccountSupervisor

  alias Zaryn.BeaconChain
  alias Zaryn.BeaconChain.Supervisor, as: BeaconChainSupervisor

  alias Zaryn.Bootstrap

  alias Zaryn.Contracts.Supervisor, as: ContractsSupervisor

  alias Zaryn.Crypto.Supervisor, as: CryptoSupervisor

  alias Zaryn.DB.Supervisor, as: DBSupervisor

  alias Zaryn.Election.Supervisor, as: ElectionSupervisor

  alias Zaryn.Governance.Supervisor, as: GovernanceSupervisor

  alias Zaryn.Mining.Supervisor, as: MiningSupervisor

  alias Zaryn.Networking

  alias Zaryn.P2P.Supervisor, as: P2PSupervisor

  alias Zaryn.OracleChain
  alias Zaryn.OracleChain.Supervisor, as: OracleChainSupervisor

  alias Zaryn.Reward
  alias Zaryn.Reward.Supervisor, as: RewardSupervisor

  alias Zaryn.SelfRepair
  alias Zaryn.SelfRepair.Supervisor, as: SelfRepairSupervisor

  alias Zaryn.SharedSecrets
  alias Zaryn.SharedSecrets.Supervisor, as: SharedSecretsSupervisor

  alias Zaryn.TransactionChain.Supervisor, as: TransactionChainSupervisor

  alias Zaryn.Utils

  alias ZarynWeb.Endpoint, as: WebEndpoint
  alias ZarynWeb.Supervisor, as: WebSupervisor

  require Logger

  def start(_type, _args) do
    p2p_endpoint_conf = Application.get_env(:zaryn, Zaryn.P2P.Endpoint)

    port = Keyword.fetch!(p2p_endpoint_conf, :port)
    Logger.info("Try to open the port #{port}")
    port = Networking.try_open_port(port, true)

    transport = Keyword.get(p2p_endpoint_conf, :transport, :tcp)

    children = [
      {Task.Supervisor, name: Zaryn.TaskSupervisor},
      Zaryn.Telemetry,
      {Registry, keys: :duplicate, name: Zaryn.PubSubRegistry},
      DBSupervisor,
      TransactionChainSupervisor,
      CryptoSupervisor,
      ElectionSupervisor,
      {P2PSupervisor, port: port},
      MiningSupervisor,
      ContractsSupervisor,
      BeaconChainSupervisor,
      SharedSecretsSupervisor,
      AccountSupervisor,
      GovernanceSupervisor,
      SelfRepairSupervisor,
      OracleChainSupervisor,
      RewardSupervisor,
      WebSupervisor,
      {Bootstrap,
       Keyword.merge(Application.get_env(:zaryn, Zaryn.Bootstrap),
         port: port,
         transport: transport
       )}
    ]

    opts = [strategy: :rest_for_one, name: Zaryn.Supervisor]
    Supervisor.start_link(Utils.configurable_children(children), opts)
  end

  def config_change(changed, _new, removed) do
    # Tell Phoenix to update the endpoint configuration
    # whenever the application is updated.
    WebEndpoint.config_change(changed, removed)

    # Update the configuration of process which depends on configuration
    SharedSecrets.config_change(changed)
    SelfRepair.config_change(changed)
    OracleChain.config_change(changed)
    Reward.config_change(changed)
    BeaconChain.config_change(changed)
    :ok
  end
end
