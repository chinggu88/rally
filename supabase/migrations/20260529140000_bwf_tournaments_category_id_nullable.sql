-- Allow NULL category_id on bwf_tournaments.
-- Non-canonical categories (Super 100, Grade 1 Team/Individual) have no entry in
-- the calendar job's _NAME_TO_CAT_ID map, so they store NULL. The NOT NULL
-- constraint was only safe while the table held the 5 World Tour grades.
alter table bwf_tournaments
  alter column category_id drop not null;
