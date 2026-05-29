-- Widen bwf_tournaments.tour_level from the 5-value enum to free text so the
-- calendar job can store ALL HSBC World Tour categories (Super 100, Grade 1 Team
-- & Individual tournaments, ...), not just FINALS / SUPER_1000..300.
--
-- Why: bwf_matches references tournaments the matches crawler found across
-- category ids 20-27; the enum silently dropped Team/Individual/Super-100 events,
-- leaving match rows with no parent tournament. Text lets the two tables cover
-- the same tournament set so a FK can be added.
--
-- Existing enum values ('SUPER_1000', ...) survive the cast unchanged.

alter table bwf_tournaments
  alter column tour_level type text using tour_level::text;

drop type if exists bwf_tour_level;
