defmodule ZarynWeb.NodeListLive do
  @moduledoc false

  use ZarynWeb, :live_view

  alias Zaryn.P2P
  alias Zaryn.PubSub

  alias ZarynWeb.NodeView

  alias Phoenix.View

  def mount(_params, _session, socket) do
    nodes = P2P.list_nodes()
    authorized_nodes = Enum.filter(nodes, & &1.authorized?)

    if connected?(socket) do
      PubSub.register_to_node_update()
    end

    new_socket =
      socket
      |> assign(:non_authorized_nodes, nodes -- authorized_nodes)
      |> assign(:authorized_nodes, authorized_nodes)
      |> assign(:nb_nodes, length(nodes))

    {:ok, new_socket}
  end

  def render(assigns) do
    View.render(NodeView, "list.html", assigns)
  end

  def handle_info({:node_update, _}, socket) do
    nodes = P2P.list_nodes()
    authorized_nodes = Enum.filter(nodes, & &1.authorized?)

    new_socket =
      socket
      |> assign(:non_authorized_nodes, nodes -- authorized_nodes)
      |> assign(:authorized_nodes, authorized_nodes)
      |> assign(:nb_nodes, length(nodes))

    {:noreply, new_socket}
  end
end
