CREATE TABLE IF NOT EXISTS zaryn.network_stats_by_date (
  date timestamp PRIMARY KEY,
  nb_transactions int,
  tps float
);
