defmodule Zaryn.P2P.Message.GetLastTransaction do
  @moduledoc """
  Represents a message to request the last transaction of a chain
  """
  @enforce_keys [:address]
  defstruct [:address]

  alias Zaryn.Crypto

  @type t :: %__MODULE__{
          address: Crypto.versioned_hash()
        }
end
