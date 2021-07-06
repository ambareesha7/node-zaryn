defmodule Zaryn.Bootstrap.TransactionHandlerTest do
  use ZarynCase

  @moduletag :capture_log

  alias Zaryn.Bootstrap.TransactionHandler

  alias Zaryn.P2P
  alias Zaryn.P2P.Message.GetTransaction
  alias Zaryn.P2P.Message.NewTransaction
  alias Zaryn.P2P.Message.Ok

  alias Zaryn.P2P.Node

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.Transaction.ValidationStamp
  alias Zaryn.TransactionChain.TransactionData

  import Mox

  test "create_node_transaction/4 should create transaction with ip and port encoded in the content" do
    assert %Transaction{
             data: %TransactionData{
               content:
                 <<127, 0, 0, 1, 3000::16, 1, _::binary-size(33), cert_size::16,
                   _::binary-size(cert_size)>>
             }
           } =
             TransactionHandler.create_node_transaction(
               {127, 0, 0, 1},
               3000,
               :tcp,
               <<0::8, :crypto.strong_rand_bytes(32)::binary>>
             )
  end

  test "send_transaction/2 should send the transaction to a welcome node" do
    node = %Node{
      ip: {80, 10, 101, 202},
      port: 4390,
      first_public_key: "key1",
      last_public_key: "key1",
      available?: true
    }

    :ok = P2P.add_and_connect_node(node)

    tx =
      TransactionHandler.create_node_transaction(
        {127, 0, 0, 1},
        3000,
        :tcp,
        "00610F69B6C5C3449659C99F22956E5F37AA6B90B473585216CF4931DAF7A0AB45"
      )

    MockClient
    |> stub(:send_message, fn
      _, %NewTransaction{} ->
        {:ok, %Ok{}}

      _, %GetTransaction{} ->
        {:ok,
         %Transaction{
           address: tx.address,
           validation_stamp: %ValidationStamp{},
           cross_validation_stamps: [%{}]
         }}
    end)

    assert :ok = TransactionHandler.send_transaction(tx, [node])
  end
end
