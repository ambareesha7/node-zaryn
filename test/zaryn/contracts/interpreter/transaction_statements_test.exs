defmodule Zaryn.Contracts.Interpreter.TransactionStatementsTest do
  use ExUnit.Case

  alias Zaryn.Contracts.Contract
  alias Zaryn.Contracts.Interpreter.TransactionStatements

  alias Zaryn.TransactionChain.Transaction
  alias Zaryn.TransactionChain.TransactionData
  alias Zaryn.TransactionChain.TransactionData.Keys
  alias Zaryn.TransactionChain.TransactionData.Ledger
  alias Zaryn.TransactionChain.TransactionData.NFTLedger
  alias Zaryn.TransactionChain.TransactionData.ZARYNLedger

  doctest TransactionStatements
end
