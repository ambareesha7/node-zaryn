defmodule ZarynWeb.UpController do
  @moduledoc false

  use ZarynWeb, :controller

  @doc """
  Respond with 200 when node is ready otherwise with 503.
  Used only to indicate that the first testnet node is bootrapped.
  """
  def up(conn, _) do
    :up = :persistent_term.get(:zaryn_up)
  rescue
    _ ->
      resp(conn, 503, "wait")
  else
    _ ->
      resp(conn, 200, "up")
  end
end
