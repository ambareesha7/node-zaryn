defmodule Zaryn.OracleChain.Services.ZARYNPrice.Providers.Impl do
  @moduledoc false

  @callback fetch(list(binary())) :: {:ok, %{required(String.t()) => any()}} | {:error, any()}
end
