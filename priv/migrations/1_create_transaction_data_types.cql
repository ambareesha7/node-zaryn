CREATE TYPE IF NOT EXISTS zaryn.zaryn_transfer(
  "to" blob,
  amount double
);

CREATE TYPE IF NOT EXISTS zaryn.zaryn_ledger(
  transfers LIST<frozen<zaryn_transfer>>
);

CREATE TYPE IF NOT EXISTS zaryn.nft_transfer(
  "to" blob,
  amount double,
  nft blob
);

CREATE TYPE IF NOT EXISTS zaryn.nft_ledger(
  transfers LIST<frozen<nft_transfer>>
);

CREATE TYPE IF NOT EXISTS zaryn.pending_transaction_data_keys(
  authorized_keys map<blob, blob>,
  secret blob
);

CREATE TYPE IF NOT EXISTS zaryn.pending_transaction_ledger(
  zaryn frozen<zaryn_ledger>,
  nft frozen<nft_ledger>
);

CREATE TYPE IF NOT EXISTS zaryn.pending_transaction_data(
  code text,
  content blob,
  recipients LIST<blob>,
  ledger frozen<pending_transaction_ledger>,
  keys frozen<pending_transaction_data_keys>
);
