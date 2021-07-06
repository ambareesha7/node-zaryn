defmodule Zaryn.Contracts.Contract.Conditions do
  @moduledoc """
  Represents the smart contract conditions
  """

  defstruct [
    :type,
    :content,
    :code,
    :authorized_keys,
    :secret,
    :zaryn_transfers,
    :nft_transfers,
    :previous_public_key,
    origin_family: :all
  ]

  alias Zaryn.SharedSecrets
  alias Zaryn.TransactionChain.Transaction

  @type t :: %__MODULE__{
          type: Transaction.transaction_type() | nil,
          content: binary() | Macro.t() | nil,
          code: binary() | Macro.t() | nil,
          authorized_keys: map() | Macro.t() | nil,
          secret: binary() | Macro.t() | nil,
          zaryn_transfers: map() | Macro.t() | nil,
          nft_transfers: map() | Macro.t() | nil,
          previous_public_key: binary() | Macro.t() | nil,
          origin_family: SharedSecrets.origin_family() | :all
        }

  def empty?(%__MODULE__{
        type: nil,
        content: nil,
        code: nil,
        authorized_keys: nil,
        secret: nil,
        zaryn_transfers: nil,
        nft_transfers: nil,
        previous_public_key: nil
      }),
      do: true

  def empty?(%__MODULE__{}), do: false
end
