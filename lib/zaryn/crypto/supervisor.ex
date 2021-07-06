defmodule Zaryn.Crypto.Supervisor do
  @moduledoc false
  use Supervisor

  alias Zaryn.Crypto
  alias Zaryn.Crypto.Ed25519.LibSodiumPort
  alias Zaryn.Crypto.KeystoreSupervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: Zaryn.CryptoSupervisor)
  end

  def init(_args) do
    load_storage_nonce()

    children = [LibSodiumPort, KeystoreSupervisor]
    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp load_storage_nonce do
    abs_filepath = Crypto.storage_nonce_filepath()
    :ok = File.mkdir_p!(Path.dirname(abs_filepath))

    case File.read(abs_filepath) do
      {:ok, storage_nonce} ->
        :persistent_term.put(:storage_nonce, storage_nonce)

      _ ->
        :ok
    end
  end
end
