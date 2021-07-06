defmodule Zaryn.Account.MemTablesLoaderTest do
  use ZarynCase

  alias Zaryn.Account.MemTables.NFTLedger
  alias Zaryn.Account.MemTables.ZARYNLedger
  alias Zaryn.Account.MemTablesLoader

  alias Zaryn.P2P
  alias Zaryn.P2P.Node

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations
  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.NodeMovement

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.TransactionMovement

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    P2P.add_and_connect_node(%Node{
      first_public_key: "NodeKey",
      last_public_key: "NodeKey",
      reward_address: "@NodeKey",
      ip: {127, 0, 0, 1},
      port: 3000,
      geo_patch: "AAA"
    })

    :ok
  end

  describe "load_transaction/1" do
    test "should distribute unspent outputs" do
      assert :ok = MemTablesLoader.load_transaction(create_transaction())

      [
        %UnspentOutput{from: "@Charlie3", amount: 19.0, type: :ZARYN},
        %UnspentOutput{from: "@Alice2", amount: 2.0, type: :ZARYN}
      ] = ZARYNLedger.get_unspent_outputs("@Charlie3")

      [%UnspentOutput{from: "@Charlie3", amount: 1.303, type: :ZARYN}] =
        ZARYNLedger.get_unspent_outputs("@NodeKey")

      [%UnspentOutput{from: "@Charlie3", amount: 34.0}] = ZARYNLedger.get_unspent_outputs("@Tom4")

      assert [%UnspentOutput{from: "@Charlie3", amount: 10.0, type: {:NFT, "@CharlieNFT"}}] =
               NFTLedger.get_unspent_outputs("@Bob3")
    end
  end

  describe "start_link/1" do
    setup do
      MockDB
      |> stub(:list_transactions, fn _fields -> [create_transaction()] end)

      :ok
    end

    test "should query DB to load all the transactions" do
      assert {:ok, _} = MemTablesLoader.start_link()

      [
        %UnspentOutput{from: "@Charlie3", amount: 19.0, type: :ZARYN},
        %UnspentOutput{from: "@Alice2", amount: 2.0, type: :ZARYN}
      ] = ZARYNLedger.get_unspent_outputs("@Charlie3")

      [%UnspentOutput{from: "@Charlie3", amount: 1.303, type: :ZARYN}] =
        ZARYNLedger.get_unspent_outputs("@NodeKey")

      [%UnspentOutput{from: "@Charlie3", amount: 34.0, type: :ZARYN}] =
        ZARYNLedger.get_unspent_outputs("@Tom4")

      assert [%UnspentOutput{from: "@Charlie3", amount: 10.0, type: {:NFT, "@CharlieNFT"}}] =
               NFTLedger.get_unspent_outputs("@Bob3")
    end
  end

  defp create_transaction do
    %Transaction{
      address: "@Charlie3",
      previous_public_key: "Charlie2",
      validation_stamp: %ValidationStamp{
        timestamp: DateTime.utc_now(),
        ledger_operations: %LedgerOperations{
          transaction_movements: [
            %TransactionMovement{to: "@Tom4", amount: 34.0, type: :ZARYN},
            %TransactionMovement{to: "@Bob3", amount: 10.0, type: {:NFT, "@CharlieNFT"}}
          ],
          node_movements: [%NodeMovement{to: "NodeKey", amount: 1.303, roles: []}],
          unspent_outputs: [
            %UnspentOutput{
              from: "@Alice2",
              amount: 2.0,
              type: :ZARYN
            },
            %UnspentOutput{from: "@Charlie3", amount: 19.0, type: :ZARYN}
          ]
        }
      }
    }
  end
end
