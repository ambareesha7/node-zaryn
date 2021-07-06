defmodule ZarynWeb.GraphQLSchema.SharedSecretsType do
  @moduledoc false

  use Absinthe.Schema.Notation

  @desc """
  [SharedSecrets] represents the public shared secret information
  It includes:
  - The storage nonce public key: Public Key to encrypt data for the node, so they will be able to decrypt it (mostly for smart contract authorized key)
  """
  object :shared_secrets do
    field(:storage_nonce_public_key, :hex)
  end
end
