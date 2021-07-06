defmodule Zaryn.Mining.PendingTransactionValidation do
  @moduledoc false

  alias Zaryn.Contracts
  alias Zaryn.Contracts.Contract

  alias Zaryn.Crypto

  alias Zaryn.Governance
  alias Zaryn.Governance.Code.Proposal, as: CodeProposal

  alias Zaryn.OracleChain

  alias Zaryn.P2P
  alias Zaryn.P2P.Message.FirstPublicKey
  alias Zaryn.P2P.Message.GetFirstPublicKey
  alias Zaryn.P2P.Node

  alias Zaryn.Replication

  alias Zaryn.Reward

  alias Zaryn.SharedSecrets.NodeRenewal

  alias Zaryn.TransactionChain
  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.TransactionData
  alias Zaryn.TransactionChain.TransactionData.Keys
  alias Zaryn.TransactionChain.TransactionData.Ledger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger

  alias Zaryn.Utils

  require Logger

  @doc """
  Determines if the transaction is accepted into the network
  """
  @spec validate(Transaction.t()) :: :ok | {:error, any()}
  def validate(tx = %Transaction{address: address, type: type}) do
    start = System.monotonic_time()

    with true <- Transaction.verify_previous_signature?(tx),
         :ok <- validate_contract(tx) do
      res = do_accept_transaction(tx)

      :telemetry.execute(
        [:zaryn, :mining, :pending_transaction_validation],
        %{duration: System.monotonic_time() - start},
        %{transaction_type: type}
      )

      res
    else
      false ->
        Logger.error("Invalid previous signature",
          transaction: "#{type}@#{Base.encode16(address)}"
        )

        {:error, "Invalid previous signature"}

      {:error, _} = e ->
        e
    end
  end

  defp validate_contract(%Transaction{data: %TransactionData{code: ""}}), do: :ok

  defp validate_contract(%Transaction{
         address: address,
         type: type,
         data: %TransactionData{code: code, keys: keys}
       }) do
    case Contracts.parse(code) do
      {:ok, %Contract{triggers: [_ | _]}} ->
        if Crypto.storage_nonce_public_key() in Keys.list_authorized_keys(keys) do
          :ok
        else
          Logger.error("Require storage nonce public key as authorized keys",
            transaction: "#{type}@#{Base.encode16(address)}"
          )

          {:error, "Requires storage nonce public key as authorized keys"}
        end

      {:ok, %Contract{}} ->
        :ok

      {:error, reason} ->
        Logger.error("Smart contract invalid #{inspect(reason)}",
          transaction: "#{type}@#{Base.encode16(address)}"
        )

        {:error, reason}
    end
  end

  defp do_accept_transaction(%Transaction{
         address: address,
         type: :node_rewards,
         data: %TransactionData{
           ledger: %Ledger{
             zaryn: %ZARYNLedger{transfers: zaryn_transfers}
           }
         }
       }) do
    case Reward.get_transfers_for_in_need_validation_nodes(Reward.last_scheduling_date()) do
      ^zaryn_transfers ->
        :ok

      _ ->
        Logger.error("Invalid network pool transfers",
          transaction: "node_rewards@#{Base.encode16(address)}"
        )

        {:error, "Invalid network pool transfers"}
    end
  end

  defp do_accept_transaction(%Transaction{
         address: address,
         type: :node,
         data: %TransactionData{
           content: content
         },
         previous_public_key: previous_public_key
       }) do
    with {:ok, _, _, _, _, key_certificate} <- Node.decode_transaction_content(content),
         root_ca_public_key <- Crypto.get_root_ca_public_key(previous_public_key),
         true <-
           Crypto.verify_key_certificate?(
             previous_public_key,
             key_certificate,
             root_ca_public_key
           ) do
      :ok
    else
      :error ->
        Logger.error("Invalid node transaction content",
          transaction: "node@#{Base.encode16(address)}"
        )

        {:error, "Invalid node transaction"}

      false ->
        Logger.error("Invalid node key certificate",
          transaction: "node@#{Base.encode16(address)}"
        )

        {:error, "Invalid node transaction"}
    end
  end

  defp do_accept_transaction(%Transaction{
         address: address,
         type: :node_shared_secrets,
         data: %TransactionData{
           content: content,
           keys: %Keys{secret: secret, authorized_keys: authorized_keys}
         }
       })
       when is_binary(secret) and byte_size(secret) > 0 and map_size(authorized_keys) > 0 do
    nodes = P2P.available_nodes()

    with {:ok, _, _} <- NodeRenewal.decode_transaction_content(content),
         true <- Enum.all?(Map.keys(authorized_keys), &Utils.key_in_node_list?(nodes, &1)) do
      :ok
    else
      :error ->
        Logger.error("Node shared secrets has invalid content",
          transaction: "node_shared_secrets@#{Base.encode16(address)}"
        )

        {:error, "Invalid node shared secrets transaction"}

      false ->
        Logger.error("Node shared secrets can only contains public node list",
          transaction: "node_shared_secrets@#{Base.encode16(address)}"
        )

        {:error, "Invalid node shared secrets transaction"}
    end
  end

  defp do_accept_transaction(%Transaction{type: :node_shared_secrets}) do
    {:error, "Invalid node shared secrets transaction"}
  end

  defp do_accept_transaction(
         tx = %Transaction{
           address: address,
           type: :code_proposal
         }
       ) do
    with {:ok, prop} <- CodeProposal.from_transaction(tx),
         true <- Governance.valid_code_changes?(prop) do
      :ok
    else
      _ ->
        Logger.error("Invalid code proposal",
          transaction: "code_proposal@#{Base.encode16(address)}"
        )

        {:error, "Invalid code proposal"}
    end
  end

  defp do_accept_transaction(
         tx = %Transaction{
           address: address,
           type: :code_approval,
           data: %TransactionData{
             recipients: [proposal_address]
           }
         }
       ) do
    first_public_key = get_first_public_key(tx)

    with {:member, true} <-
           {:member, Governance.pool_member?(first_public_key, :technical_council)},
         {:ok, prop} <- Governance.get_code_proposal(proposal_address),
         previous_address <- Transaction.previous_address(tx),
         {:signed, false} <- {:signed, CodeProposal.signed_by?(prop, previous_address)} do
      :ok
    else
      {:member, false} ->
        Logger.error("No technical council member",
          transaction: "code_approval@#{Base.encode16(address)}"
        )

        {:error, "No technical council member"}

      {:error, :not_found} ->
        Logger.error("Code proposal does not exist",
          transaction: "code_approval@#{Base.encode16(address)}"
        )

        {:error, "Code proposal doest not exist"}

      {:signed, true} ->
        Logger.error("Code proposal already signed",
          transaction: "code_approval@#{Base.encode16(address)}"
        )

        {:error, "Code proposal already signed"}
    end
  end

  defp do_accept_transaction(%Transaction{
         address: address,
         type: :nft,
         data: %TransactionData{content: content}
       }) do
    if Regex.match?(~r/(?<=initial supply:).*\d/mi, content) do
      :ok
    else
      Logger.error("Invalid NFT transaction content", transaction: "nft@#{Base.encode16(address)}")

      {:error, "Invalid NFT content"}
    end
  end

  defp do_accept_transaction(%Transaction{
         address: address,
         type: :oracle,
         data: %TransactionData{
           content: content
         }
       }) do
    if OracleChain.valid_services_content?(content) do
      :ok
    else
      Logger.error("Invalid oracle transaction", transaction: "oracle@#{Base.encode16(address)}")
      {:error, "Invalid oracle transaction"}
    end
  end

  defp do_accept_transaction(%Transaction{
         address: address,
         type: :oracle_summary,
         data: %TransactionData{
           content: content
         },
         previous_public_key: previous_public_key
       }) do
    with previous_address <- Crypto.hash(previous_public_key),
         oracle_chain <-
           TransactionChain.get(previous_address, data: [:content], validation_stamp: [:timestamp]),
         true <- OracleChain.valid_summary?(content, oracle_chain) do
      :ok
    else
      _ ->
        Logger.error("Invalid oracle summary transaction",
          transaction: "oracle_summary@#{Base.encode16(address)}"
        )

        {:error, "Invalid oracle summary transaction"}
    end
  end

  defp do_accept_transaction(_), do: :ok

  defp get_first_public_key(tx = %Transaction{previous_public_key: previous_public_key}) do
    previous_address = Transaction.previous_address(tx)

    storage_nodes = Replication.chain_storage_nodes(previous_address)

    response_message =
      P2P.reply_first(storage_nodes, %GetFirstPublicKey{address: previous_address})

    case response_message do
      {:ok, %FirstPublicKey{public_key: public_key}} ->
        public_key

      _ ->
        previous_public_key
    end
  end
end
