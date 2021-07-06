defmodule ZarynWeb.TransactionBuilderLive do
  @moduledoc false

  use ZarynWeb, :live_component

  alias Phoenix.View

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    View.render(ZarynWeb.ExplorerView, "transaction_builder.html", assigns)
  end
end
