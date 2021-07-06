defmodule Zaryn.P2P.Client do
  @moduledoc false

  alias Zaryn.Crypto

  alias __MODULE__.DefaultImpl

  alias Zaryn.P2P.Message
  alias Zaryn.P2P.Node
  alias Zaryn.P2P.Transport

  use Knigge, otp_app: :zaryn, default: DefaultImpl

  @callback new_connection(
              :inet.ip_address(),
              port :: :inet.port_number(),
              Transport.supported(),
              Crypto.key()
            ) :: {:ok, pid()}

  @callback send_message(Node.t(), Message.request()) ::
              {:ok, Message.response()} | {:error, :network_issue}
end
