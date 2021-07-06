defmodule Zaryn.DB.CassandraImpl.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.DB.CassandraImpl.Consumer
  alias Zaryn.DB.CassandraImpl.Producer
  alias Zaryn.DB.CassandraImpl.SchemaMigrator

  require Logger

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args)
  end

  def init(_args) do
    host = Application.get_env(:zaryn, Zaryn.DB.CassandraImpl) |> Keyword.fetch!(:host)

    Logger.info("Start Cassandra connection at #{host}")

    children = [
      {Xandra, name: :xandra_conn, pool_size: 10, nodes: [host]},
      Producer,
      Consumer,
      SchemaMigrator
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
