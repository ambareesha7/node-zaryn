import Config

# Print only errors during test
config :logger, level: :error

config :zaryn, :mut_dir, "data_test"

config :zaryn, Zaryn.Account.MemTablesLoader, enabled: false
config :zaryn, Zaryn.Account.MemTables.NFTLedger, enabled: false
config :zaryn, Zaryn.Account.MemTables.ZARYNLedger, enabled: false

config :zaryn, Zaryn.BeaconChain.Subset, enabled: false

config :zaryn, Zaryn.BeaconChain.SlotTimer,
  enabled: false,
  interval: "0 * * * * *"

config :zaryn, Zaryn.BeaconChain.SummaryTimer,
  enabled: false,
  interval: "0 * * * * *"

config :zaryn, Zaryn.Bootstrap, enabled: false

config :zaryn, Zaryn.Bootstrap.Sync, out_of_sync_date_threshold: 3

config :zaryn, Zaryn.Contracts.Loader, enabled: false

config :zaryn, Zaryn.Crypto,
  root_ca_public_keys: [
    #  From `:crypto.generate_key(:ecdh, :secp256r1, "ca_root_key")`
    software:
      <<4, 210, 136, 107, 189, 140, 118, 86, 124, 217, 244, 69, 111, 61, 56, 224, 56, 150, 230,
        194, 203, 81, 213, 212, 220, 19, 1, 180, 114, 44, 230, 149, 21, 125, 69, 206, 32, 173,
        186, 81, 243, 58, 13, 198, 129, 169, 33, 179, 201, 50, 49, 67, 38, 156, 38, 199, 97, 59,
        70, 95, 28, 35, 233, 21, 230>>,
    tpm:
      <<4, 210, 136, 107, 189, 140, 118, 86, 124, 217, 244, 69, 111, 61, 56, 224, 56, 150, 230,
        194, 203, 81, 213, 212, 220, 19, 1, 180, 114, 44, 230, 149, 21, 125, 69, 206, 32, 173,
        186, 81, 243, 58, 13, 198, 129, 169, 33, 179, 201, 50, 49, 67, 38, 156, 38, 199, 97, 59,
        70, 95, 28, 35, 233, 21, 230>>
  ],
  software_root_ca_key: :crypto.generate_key(:ecdh, :secp256r1, "ca_root_key") |> elem(1)

config :zaryn, Zaryn.Crypto.NodeKeystore, MockCrypto
config :zaryn, Zaryn.Crypto.NodeKeystore.SoftwareImpl, seed: "fake seed"
config :zaryn, Zaryn.Crypto.SharedSecretsKeystore, MockCrypto
config :zaryn, Zaryn.Crypto.KeystoreCounter, enabled: false
config :zaryn, Zaryn.Crypto.KeystoreLoader, enabled: false

config :zaryn, MockCrypto, enabled: false

config :zaryn, Zaryn.DB, MockDB
config :zaryn, MockDB, enabled: false

config :zaryn, Zaryn.Election.Constraints, enabled: false

config :zaryn, Zaryn.Governance.Code.TestNet, MockTestnet

config :zaryn, Zaryn.Governance.Pools,
  initial_members: [
    technical_council: [],
    ethical_council: [],
    foundation: [],
    archethic: []
  ]

config :zaryn, Zaryn.Governance.Pools.MemTable, enabled: false
config :zaryn, Zaryn.Governance.Pools.MemTableLoader, enabled: false

config :zaryn, Zaryn.OracleChain.MemTable, enabled: false
config :zaryn, Zaryn.OracleChain.MemTableLoader, enabled: false

config :zaryn, Zaryn.OracleChain.Scheduler,
  enabled: false,
  polling_interval: "0 0 * * * *",
  summary_interval: "0 0 0 * * *"

config :zaryn, Zaryn.OracleChain.Services.ZARYNPrice, provider: MockZARYNPriceProvider

config :zaryn, Zaryn.Networking.IPLookup, MockIPLookup
config :zaryn, Zaryn.Networking.PortForwarding, MockPortForwarding

config :zaryn, Zaryn.P2P.Endpoint.Listener, enabled: false
config :zaryn, Zaryn.P2P.MemTableLoader, enabled: false
config :zaryn, Zaryn.P2P.MemTable, enabled: false
config :zaryn, Zaryn.P2P.Client, MockClient
config :zaryn, Zaryn.P2P.Transport, MockTransport

config :zaryn, Zaryn.P2P.BootstrappingSeeds, enabled: false

config :zaryn, Zaryn.Reward.NetworkPoolScheduler, enabled: false
config :zaryn, Zaryn.Reward.WithdrawScheduler, enabled: false

config :zaryn, Zaryn.SelfRepair.Scheduler,
  enabled: false,
  interval: 0

config :zaryn, Zaryn.SelfRepair.Notifier, enabled: false

config :zaryn, Zaryn.SelfRepair.Sync,
  network_startup_date: DateTime.utc_now(),
  last_sync_file: "p2p/last_sync_test"

config :zaryn, Zaryn.SharedSecrets.MemTablesLoader, enabled: false
config :zaryn, Zaryn.SharedSecrets.MemTables.NetworkLookup, enabled: false
config :zaryn, Zaryn.SharedSecrets.MemTables.OriginKeyLookup, enabled: false

config :zaryn, Zaryn.SharedSecrets.NodeRenewalScheduler,
  enabled: false,
  interval: "0 0 * * * * *",
  application_interval: "0 0 * * * * *"

config :zaryn, Zaryn.TransactionChain.MemTables.PendingLedger, enabled: false
config :zaryn, Zaryn.TransactionChain.MemTables.KOLedger, enabled: false
config :zaryn, Zaryn.TransactionChain.MemTablesLoader, enabled: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :zaryn, ZarynWeb.Endpoint,
  http: [port: 4002],
  server: false
