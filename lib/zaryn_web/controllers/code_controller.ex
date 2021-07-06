defmodule ZarynWeb.CodeController do
  @moduledoc false
  use ZarynWeb, :controller

  alias Zaryn.Utils

  # alias Zaryn.TransactionChain

  # alias ZarynWeb.CodeProposalDetailsLive
  # alias ZarynWeb.ExplorerView

  @src_dir Application.compile_env(:zaryn, :src_dir)

  # def show_proposal(conn, %{"address" => address}) do
  #   # case Base.decode16(address, case: :mixed) do
  #   #   {:ok, addr} ->
  #   #     if TransactionChain.transaction_ko?(addr) do
  #   #       conn
  #   #       |> put_view(ExplorerView)
  #   #       |> render("ko_transaction.html", address: addr, errors: [])
  #   #     else
  #   #       live_render(conn, CodeProposalDetailsLive, session: %{"address" => addr})
  #   #     end
  #   #   _ ->
  #       live_render(conn, CodeProposalDetailsLive, session: %{"address" => address})
  #   # end
  # end

  def download(conn, _) do
    archive_file = Utils.mut_dir("priv/zaryn_node.zip")

    case System.cmd("git", ["archive", "-o", archive_file, "master"], cd: @src_dir) do
      {"", 0} ->
        conn
        |> put_resp_content_type("application/zip, application/octet-stream")
        |> put_resp_header("Content-disposition", "attachment; filename=\"zaryn_node.zip\"")
        |> send_file(200, archive_file)

      {reason, status} ->
        conn
        |> put_status(500)
        |> json(%{status: status, message: reason})
    end
  end
end
