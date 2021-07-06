defmodule Zaryn.Account.MemTables.NFTLedgerTest do
  use ExUnit.Case

  alias Zaryn.Account.MemTables.NFTLedger

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Zaryn.TransactionChain.TransactionInput

  doctest NFTLedger
end
