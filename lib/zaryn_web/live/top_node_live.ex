defmodule ZarynWeb.TopNodeLive do
  @moduledoc false
  use ZarynWeb, :live_view

  alias Phoenix.View

  alias Zaryn.P2P
  alias Zaryn.P2P.Node

  alias Zaryn.PubSub

  alias ZarynWeb.ExplorerView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.register_to_node_update()
    end

    {:ok, assign(socket, :nodes, top_nodes(P2P.list_nodes()))}
  end

  def render(assigns) do
    View.render(ExplorerView, "top_nodes.html", assigns)
  end

  def handle_info({:node_update, node = %Node{}}, socket) do
    new_socket =
      update(socket, :nodes, fn nodes ->
        [node | nodes]
        |> Enum.uniq_by(& &1.first_public_key)
        |> top_nodes
      end)

    {:noreply, new_socket}
  end

  defp top_nodes(nodes) do
    nodes
    |> Enum.filter(& &1.available?)
    |> Enum.sort_by(& &1.average_availability, :desc)
    |> Enum.take(10)
  end
end
