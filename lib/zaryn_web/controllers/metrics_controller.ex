defmodule ZarynWeb.MetricsController do
  alias TelemetryMetricsPrometheus.Core
  use ZarynWeb, :controller

  def index(conn, _params) do
    metrics = Core.scrape()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
end
