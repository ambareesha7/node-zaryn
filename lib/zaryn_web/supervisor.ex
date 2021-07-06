defmodule ZarynWeb.Supervisor do
  @moduledoc false

  use Supervisor

  alias Zaryn.Networking

  alias ZarynWeb.Endpoint
  alias ZarynWeb.TransactionSubscriber

  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    # Try to open the HTTP/HTTPS port
    endpoint_conf = Application.get_env(:zaryn, ZarynWeb.Endpoint)

    try_open_port(Keyword.get(endpoint_conf, :http))
    try_open_port(Keyword.get(endpoint_conf, :https))

    children = [
      {Phoenix.PubSub, [name: ZarynWeb.PubSub, adapter: Phoenix.PubSub.PG2]},
      # Start the endpoint when the application starts
      Endpoint,
      {Absinthe.Subscription, Endpoint},
      TransactionSubscriber
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  defp try_open_port(nil), do: :ok

  defp try_open_port(conf) do
    port = Keyword.get(conf, :port)
    Logger.info("Try to open the port #{port}")
    Networking.try_open_port(port, false)
  end
end
