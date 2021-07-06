defmodule Zaryn.OracleChain.Services.ZARYNPrice.Providers.Coingecko do
  @moduledoc false

  alias Zaryn.OracleChain.Services.ZARYNPrice.Providers.Impl

  @behaviour Impl

  require Logger

  @impl Impl
  @spec fetch(list(binary())) :: {:ok, %{required(String.t()) => any()}} | {:error, any()}
  def fetch(pairs) when is_list(pairs) do
    pairs_str = Enum.join(pairs, ",")

    query =
      String.to_charlist(
        "https://api.coingecko.com/api/v3/simple/price?ids=zaryn&vs_currencies=#{pairs_str}"
      )

    with {:ok, {{_, 200, 'OK'}, _headers, body}} <-
           :httpc.request(:get, {query, []}, [], []),
         {:ok, payload} <- Jason.decode(body),
         {:ok, prices} <- Map.fetch(payload, "zaryn") do
      {:ok, prices}
    end
  end
end
