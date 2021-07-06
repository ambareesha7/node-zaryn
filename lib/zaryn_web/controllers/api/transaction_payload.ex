defmodule ZarynWeb.API.TransactionPayload do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Zaryn.Utils

  alias ZarynWeb.API.Types.AddressList
  alias ZarynWeb.API.Types.AuthorizedKeys
  alias ZarynWeb.API.Types.Hash
  alias ZarynWeb.API.Types.Hex
  alias ZarynWeb.API.Types.PublicKey
  alias ZarynWeb.API.Types.TransactionType

  embedded_schema do
    field(:version, :integer)
    field(:address, Hash)
    field(:type, TransactionType)

    embeds_one :data, TransactionData do
      field(:content, Hex)
      field(:code, :binary)

      embeds_one :ledger, Ledger do
        embeds_one :zaryn, ZARYNLedger do
          embeds_many :transfers, Transfer do
            field(:to, Hash)
            field(:amount, :float)
          end
        end

        embeds_one :nft, NFT do
          embeds_many :transfers, Transfer do
            field(:to, Hash)
            field(:amount, :float)
            field(:nft, Hash)
          end
        end
      end

      embeds_one :keys, Keys do
        field(:secret, Hex)
        field(:authorizedKeys, AuthorizedKeys)
      end

      field(:recipients, AddressList)
    end

    field(:previousPublicKey, PublicKey)
    field(:previousSignature, Hex)
    field(:originSignature, Hex)
  end

  def changeset(params = %{}) do
    %__MODULE__{}
    |> cast(params, [
      :version,
      :address,
      :type,
      :previousPublicKey,
      :previousSignature,
      :originSignature
    ])
    |> validate_required([
      :version,
      :address,
      :type,
      :previousPublicKey,
      :previousSignature,
      :originSignature
    ])
    |> cast_embed(:data, required: true, with: &changeset_data/2)
  end

  defp changeset_data(changeset, params) do
    changeset
    |> cast(params, [:content, :code, :recipients])
    |> cast_embed(:keys, with: &changeset_keys/2)
    |> cast_embed(:ledger, with: &changeset_ledger/2)
  end

  defp changeset_keys(changeset, params) do
    changeset
    |> cast(params, [:secret, :authorizedKeys])
  end

  defp changeset_ledger(changeset, params) do
    changeset
    |> cast(params, [])
    |> cast_embed(:zaryn, with: &changeset_zaryn_ledger/2)
    |> cast_embed(:nft, with: &changeset_nft_ledger/2)
  end

  defp changeset_zaryn_ledger(changeset, params) do
    changeset
    |> cast(params, [])
    |> cast_embed(:transfers, with: &changeset_zaryn_transfer/2)
  end

  defp changeset_zaryn_transfer(changeset, params) do
    changeset
    |> cast(params, [:to, :amount])
    |> validate_required([:to, :amount])
  end

  defp changeset_nft_ledger(changeset, params) do
    changeset
    |> cast(params, [])
    |> cast_embed(:transfers, with: &changeset_nft_transfer/2)
  end

  defp changeset_nft_transfer(changeset, params) do
    changeset
    |> cast(params, [:to, :amount, :nft])
    |> validate_required([:to, :amount, :nft])
  end

  def to_map(changes, acc \\ %{})

  def to_map(%{changes: changes}, acc) do
    Enum.reduce(changes, acc, fn {key, value}, acc ->
      key = Macro.underscore(Atom.to_string(key))

      case value do
        %{changes: _} ->
          Map.put(acc, key, to_map(value))

        value when is_list(value) ->
          Map.put(acc, key, Enum.map(value, &to_map/1))

        _ ->
          Map.put(acc, key, value)
      end
    end)
    |> Utils.atomize_keys()
  end

  def to_map(value, _), do: value
end
