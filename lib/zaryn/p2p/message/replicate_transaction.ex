defmodule Zaryn.P2P.Message.ReplicateTransaction do
  @moduledoc """
  Represents a message to initiate the replication of the transaction
  """
  @enforce_keys [:transaction]
  defstruct [:transaction, roles: [], ack_storage?: false, welcome_node_public_key: nil]

  alias Zaryn.Crypto

  alias Zaryn.Replication
  alias Zaryn.TransactionChain.Transaction

  @type t :: %__MODULE__{
          transaction: Transaction.t(),
          roles: list(Replication.role()),
          ack_storage?: boolean(),
          welcome_node_public_key: Crypto.key()
        }
end
