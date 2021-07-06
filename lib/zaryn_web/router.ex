defmodule ZarynWeb.Router do
  @moduledoc false

  use ZarynWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_root_layout, {ZarynWeb.LayoutView, :root})
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Add the on chain implementation of the archethic.io at the root of the webserver
  # TODO: review to put it on every node or as proxy somewhere forwarding to a specific transaction chain explorer
  scope "/", ZarynWeb do
    pipe_through(:browser)

    get("/", RootController, :index)
    get("/up", UpController, :up)
    get("/metrics", MetricsController, :index)
    live_dashboard("/dashboard", metrics: Zaryn.Telemetry)
  end

  scope "/explorer", ZarynWeb do
    pipe_through(:browser)

    live("/", ExplorerIndexLive)
    live("/transactions", TransactionListLive)
    live("/transaction/:address", TransactionDetailsLive)
    get("/chain", ExplorerController, :chain)
    live("/nodes", NodeListLive)
    live("/node/:public_key", NodeDetailsLive)
    live("/code/viewer", CodeViewerLive)
    live("/code/proposals", CodeProposalsLive)
    live("/code/proposal/:address", CodeProposalDetailsLive)
    get("/code/download", CodeController, :download)
  end

  scope "/api" do
    pipe_through(:api)

    get(
      "/last_transaction/:address/content",
      ZarynWeb.API.TransactionController,
      :last_transaction_content
    )

    post("/transaction", ZarynWeb.API.TransactionController, :new)

    forward(
      "/graphiql",
      Absinthe.Plug.GraphiQL,
      schema: ZarynWeb.GraphQLSchema,
      socket: ZarynWeb.UserSocket
    )

    forward(
      "/",
      Absinthe.Plug,
      schema: ZarynWeb.GraphQLSchema
    )
  end
end
