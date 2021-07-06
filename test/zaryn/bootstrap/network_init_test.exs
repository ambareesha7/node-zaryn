defmodule Zaryn.Bootstrap.NetworkInitTest do
  use ZarynCase

  alias Zaryn.Account
  alias Zaryn.Crypto

  alias Zaryn.BeaconChain
  alias Zaryn.BeaconChain.Slot, as: BeaconSlot
  alias Zaryn.BeaconChain.Slot.TransactionSummary
  alias Zaryn.BeaconChain.SlotTimer, as: BeaconSlotTimer
  alias Zaryn.BeaconChain.Subset, as: BeaconSubset
  alias Zaryn.BeaconChain.SubsetRegistry, as: BeaconSubsetRegistry

  alias Zaryn.Bootstrap.NetworkInit

  alias Zaryn.P2P
  alias Zaryn.P2P.Message.GetLastTransactionAddress
  alias Zaryn.P2P.Message.GetTransactionChain
  alias Zaryn.P2P.Message.GetUnspentOutputs
  alias Zaryn.P2P.Message.LastTransactionAddress
  alias Zaryn.P2P.Message.TransactionList
  alias Zaryn.P2P.Message.UnspentOutputList
  alias Zaryn.P2P.Node

  alias Zaryn.SharedSecrets
  alias Zaryn.SharedSecrets.MemTables.NetworkLookup
  alias Zaryn.SharedSecrets.NodeRenewalScheduler

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.TransactionMovement

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Zaryn.TransactionChain.TransactionData
  alias Zaryn.TransactionChain.TransactionData.Ledger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger.Transfer
  alias Zaryn.TransactionFactory

  import Mox

  setup do
    start_supervised!({BeaconSlotTimer, interval: "0 * * * * * *"})
    Enum.each(BeaconChain.list_subsets(), &BeaconSubset.start_link(subset: &1))
    start_supervised!({NodeRenewalScheduler, interval: "*/2 * * * * * *"})

    P2P.add_and_connect_node(%Node{
      ip: {127, 0, 0, 1},
      port: 3000,
      first_public_key: Crypto.first_node_public_key(),
      last_public_key: Crypto.first_node_public_key(),
      available?: true,
      geo_patch: "AAA",
      network_patch: "AAA",
      enrollment_date: DateTime.utc_now(),
      authorization_date: DateTime.utc_now(),
      authorized?: true,
      reward_address: <<0::8, :crypto.strong_rand_bytes(32)::binary>>
    })

    MockClient
    |> stub(:send_message, fn _, %GetLastTransactionAddress{address: address} ->
      {:ok, %LastTransactionAddress{address: address}}
    end)

    :ok
  end

  test "create_storage_nonce/0 should initialize the nonce in the crypto keystore" do
    assert :ok = NetworkInit.create_storage_nonce()
  end

  test "self_validation!/2 should return a validated transaction" do
    tx =
      Transaction.new(
        :transfer,
        %TransactionData{
          ledger: %Ledger{
            zaryn: %ZARYNLedger{
              transfers: [
                %Transfer{to: "@Alice2", amount: 5_000.0}
              ]
            }
          }
        },
        "seed",
        0
      )

    unspent_outputs = [%UnspentOutput{amount: 10_000, from: tx.address, type: :ZARYN}]
    tx = NetworkInit.self_validation(tx, unspent_outputs)

    assert %Transaction{
             validation_stamp: %ValidationStamp{
               ledger_operations: %LedgerOperations{
                 transaction_movements: [
                   %TransactionMovement{
                     to: <<0::8, 0::256>>,
                     amount: 0.5000003000000001,
                     type: :ZARYN
                   },
                   %TransactionMovement{to: "@Alice2", amount: 5_000.0, type: :ZARYN}
                 ],
                 unspent_outputs: [
                   %UnspentOutput{amount: 4994.999997, from: _, type: :ZARYN}
                 ]
               }
             }
           } = tx
  end

  test "self_replication/1 should insert the transaction and add to the beacon chain" do
    inputs = [
      %UnspentOutput{amount: 4999.99, from: "genesis", type: :ZARYN}
    ]

    MockClient
    |> stub(:send_message, fn
      _, %GetTransactionChain{} ->
        {:ok, %TransactionList{transactions: []}}

      _, %GetUnspentOutputs{} ->
        {:ok, %UnspentOutputList{unspent_outputs: inputs}}
    end)

    Crypto.generate_deterministic_keypair("daily_nonce_seed")
    |> elem(0)
    |> NetworkLookup.set_daily_nonce_public_key(DateTime.utc_now())

    tx =
      TransactionFactory.create_valid_transaction(
        %{
          welcome_node: P2P.get_node_info(),
          coordinator_node: P2P.get_node_info(),
          storage_nodes: [P2P.get_node_info()]
        },
        inputs,
        type: :transfer
      )

    me = self()

    MockDB
    |> stub(:write_transaction_chain, fn _chain ->
      send(me, :write_transaction)
      :ok
    end)

    NetworkInit.self_replication(tx)

    assert_received :write_transaction

    subset = BeaconChain.subset_from_address(tx.address)
    [{pid, _}] = Registry.lookup(BeaconSubsetRegistry, subset)

    tx_address = tx.address

    %{
      current_slot: %BeaconSlot{
        transaction_summaries: [
          %TransactionSummary{address: ^tx_address}
        ]
      }
    } = :sys.get_state(pid)
  end

  test "init_node_shared_secrets_chain/1 should create node shared secrets transaction chain, load daily nonce and authorize node" do
    MockClient
    |> stub(:send_message, fn
      _, %GetTransactionChain{} ->
        {:ok, %TransactionList{transactions: []}}

      _, %GetUnspentOutputs{} ->
        {:ok, %UnspentOutputList{unspent_outputs: []}}
    end)

    me = self()

    P2P.add_and_connect_node(%Node{
      first_public_key: Crypto.last_node_public_key(),
      last_public_key: Crypto.last_node_public_key(),
      ip: {127, 0, 0, 1},
      port: 3000,
      available?: true,
      authorized?: true,
      authorization_date: DateTime.utc_now(),
      geo_patch: "AAA",
      network_patch: "AAA",
      reward_address: <<0::8, :crypto.strong_rand_bytes(32)::binary>>
    })

    MockDB
    |> expect(:write_transaction_chain, fn [tx] ->
      send(me, {:transaction, tx})
      :ok
    end)

    MockCrypto
    |> stub(:unwrap_secrets, fn _, _, _ ->
      send(me, :set_daily_nonce)
      send(me, :set_transaction_seed)
      send(me, :set_network_pool)
      :ok
    end)
    |> stub(:sign_with_daily_nonce_key, fn data, _ ->
      pv =
        Application.get_env(:zaryn, Zaryn.Bootstrap.NetworkInit)
        |> Keyword.fetch!(:genesis_daily_nonce_seed)
        |> Crypto.generate_deterministic_keypair()
        |> elem(1)

      Crypto.sign(data, pv)
    end)

    NetworkInit.init_node_shared_secrets_chain()

    assert_receive {:transaction, %Transaction{type: :node_shared_secrets}}
    assert_receive :set_network_pool
    assert_receive :set_daily_nonce
    assert_receive :set_transaction_seed

    assert %Node{authorized?: true} = P2P.get_node_info()
  end

  test "init_genesis_wallets/1 should initialize genesis wallets" do
    MockClient
    |> stub(:send_message, fn
      _, %GetTransactionChain{} ->
        {:ok, %TransactionList{transactions: []}}

      _, %GetUnspentOutputs{} ->
        {:ok, %UnspentOutputList{unspent_outputs: []}}
    end)

    P2P.add_and_connect_node(%Node{
      first_public_key: Crypto.last_node_public_key(),
      last_public_key: Crypto.last_node_public_key(),
      ip: {127, 0, 0, 1},
      port: 3000,
      available?: true,
      enrollment_date: DateTime.utc_now(),
      network_patch: "AAA",
      authorization_date: DateTime.utc_now(),
      authorized?: true,
      reward_address: <<0::8, :crypto.strong_rand_bytes(32)::binary>>
    })

    Crypto.generate_deterministic_keypair("daily_nonce_seed")
    |> elem(0)
    |> NetworkLookup.set_daily_nonce_public_key(DateTime.utc_now())

    assert :ok = NetworkInit.init_genesis_wallets()

    funding_address =
      Application.get_env(:Zaryn, NetworkInit)
      |> get_in([:genesis_pools, :funding, :public_key])
      |> Base.decode16!()
      |> Crypto.hash()

    assert %{zaryn: 3.82e9} = Account.get_balance(funding_address)
    assert %{zaryn: 1.46e9} = Account.get_balance(SharedSecrets.get_network_pool_address())
  end
end
