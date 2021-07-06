defmodule Zaryn.P2P.Message.Balance do
  @moduledoc """
  Represents a message with the balance of a transaction
  """
  defstruct zaryn: 0.0, nft: %{}

  @type t :: %__MODULE__{
          zaryn: float(),
          nft: %{binary() => float()}
        }
end
