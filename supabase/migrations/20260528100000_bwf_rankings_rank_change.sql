-- Per-row rank movement vs the previous publication week.
-- Source: vue-rankingtable JSON row.rank_change, which the BWF API computes as
-- (rank_previous - rank). Convention:
--   positive = player improved (moved up the rankings; UI shows green)
--   negative = player dropped (UI shows red)
--   0        = no change
--   NULL     = new entry or unknown (API may return null for fresh entries)
alter table bwf_rankings
  add column rank_change int;
