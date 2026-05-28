-- Per-player BWF detail page URLs on bwf_rankings.
-- Derived from player1_id / player2_id via https://bwfbadminton.com/player/{id}/
-- (BWF auto-redirects to /player/{id}/{slug}/). Singles rows populate
-- player1_detail_url only; doubles populate both. Nullable: rows whose
-- member_id never resolved to a numeric ID stay NULL.
alter table bwf_rankings
  add column player1_detail_url text,
  add column player2_detail_url text;

-- Backfill existing rows. Depends on player1_id / player2_id being populated,
-- which bwf_backfill_ranking_player_ids() (defined in 20260527120000) handles.
update bwf_rankings
   set player1_detail_url = case
         when player1_id is not null
           then 'https://bwfbadminton.com/player/' || player1_id::text || '/'
         else null
       end,
       player2_detail_url = case
         when player2_id is not null
           then 'https://bwfbadminton.com/player/' || player2_id::text || '/'
         else null
       end
 where player1_id is not null
    or player2_id is not null;
