defmodule Zaryn.P2P.Message.TransactionInputList do
  @moduledoc """
  Represents a message with a list of transaction inputs
  """
  defstruct inputs: []

  alias Zaryn.TransactionChain.TransactionInput

  @type t() :: %__MODULE__{
          inputs: list(TransactionInput.t())
        }
end
