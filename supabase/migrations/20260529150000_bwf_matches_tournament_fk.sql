-- Link bwf_matches to bwf_tournaments by the BWF tournament number.
-- bwf_tournaments.tournament_id is UNIQUE (bwf_tournaments_tournament_id_key), so
-- it can be a FK target. Deferrable so a single run may upsert tournaments and
-- matches in either order within one transaction.
--
-- Prereq: the calendar job must cover every category a match can belong to
-- (Super 100 / Team / Individual included) — see the tour_level text migration —
-- otherwise inserting a match for an uncrawled tournament fails this constraint.
alter table bwf_matches
  add constraint bwf_matches_tournament_fk
    foreign key (tournament_id)
    references bwf_tournaments (tournament_id)
    on delete cascade
    deferrable initially deferred;
