defmodule Zaryn.P2P.Message.TransactionList do
  @moduledoc """
  Represents a message with a list of transactions
  """
  defstruct transactions: []

  alias Zaryn.TransactionChain.Transaction

  @type t :: %__MODULE__{
          transactions: list(Transaction.t())
        }
end
