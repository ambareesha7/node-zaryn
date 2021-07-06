defmodule Zaryn.Account.MemTables.ZARYNLedgerTest do
  use ExUnit.Case

  alias Zaryn.Account.MemTables.ZARYNLedger

  alias Zaryn.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Zaryn.TransactionChain.TransactionInput

  doctest ZARYNLedger
end
