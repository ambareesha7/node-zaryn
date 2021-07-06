import Config

config :zaryn, :mut_dir, "data_#{System.get_env("ZARYN_CRYPTO_SEED", "node1")}"

config :telemetry_poller, :default, period: 5_000

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :zaryn, Zaryn.BeaconChain.SlotTimer,
  # Every 10 seconds
  interval: "*/10 * * * * *"

config :zaryn, Zaryn.BeaconChain.SummaryTimer,
  # Every minute
  interval: "0 * * * * *"

config :zaryn, Zaryn.Bootstrap,
  reward_address:
    System.get_env(
      "ZARYN_REWARD_ADDRESS",
      Base.encode16(<<0::8, :crypto.strong_rand_bytes(32)::binary>>)
    )
    |> Base.decode16!(case: :mixed)

config :zaryn, Zaryn.Bootstrap.Sync, out_of_sync_date_threshold: 60

config :zaryn, Zaryn.P2P.BootstrappingSeeds,
  # First node crypto seed is "node1"
  genesis_seeds:
    System.get_env(
      "ZARYN_P2P_BOOTSTRAPPING_SEEDS",
      "127.0.0.1:3002:00001D967D71B2E135C84206DDD108B5925A2CD99C8EBC5AB5D8FD2EC9400CE3C98A:tcp"
    )

config :zaryn,
       Zaryn.Crypto.NodeKeystore,
       (case System.get_env("ZARYN_CRYPTO_NODE_KEYSTORE_IMPL", "SOFTWARE") do
          "SOFTWARE" ->
            Zaryn.Crypto.NodeKeystore.SoftwareImpl

          "TPM" ->
            Zaryn.Crypto.NodeKeystore.TPMImpl
        end)

config :zaryn, Zaryn.Crypto.NodeKeystore.SoftwareImpl,
  seed: System.get_env("ZARYN_CRYPTO_SEED", "node1")

config :zaryn, Zaryn.DB.CassandraImpl, host: System.get_env("ZARYN_DB_HOST", "127.0.0.1:9042")

config :zaryn, Zaryn.Governance.Pools,
  initial_members: [
    technical_council: [
      {"00001D967D71B2E135C84206DDD108B5925A2CD99C8EBC5AB5D8FD2EC9400CE3C98A", 1}
    ],
    ethical_council: [],
    foundation: [],
    uniris: []
  ]

config :zaryn, Zaryn.OracleChain.Scheduler,
  # Poll new changes every 10 seconds
  polling_interval: "*/10 * * * * *",
  # Aggregate chain at the 50th second
  summary_interval: "50 * * * * *"

config :zaryn, Zaryn.Networking.IPLookup, Zaryn.Networking.IPLookup.Static

config :zaryn, Zaryn.Networking.IPLookup.Static,
  hostname: System.get_env("ZARYN_STATIC_IP", "127.0.0.1")

config :zaryn, Zaryn.Reward.NetworkPoolScheduler,
  # At the 30th second
  interval: "30 * * * * *"

config :zaryn, Zaryn.Reward.WithdrawScheduler,
  # Every 10s
  interval: "*/10 * * * * *"

config :zaryn, Zaryn.SelfRepair.Scheduler,
  # Every minute
  interval: "5 * * * * * *"

config :zaryn, Zaryn.SharedSecrets.NodeRenewalScheduler,
  # At 40th second
  interval: "40 * * * * * *",
  application_interval: "0 * * * * * *"

config :zaryn, Zaryn.P2P.Endpoint,
  port: System.get_env("ZARYN_P2P_PORT", "3002") |> String.to_integer()

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :zaryn, ZarynWeb.Endpoint,
  http: [port: System.get_env("ZARYN_HTTP_PORT", "4000") |> String.to_integer()],
  server: true,
  debug_errors: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]
