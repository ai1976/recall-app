-- [SCHEMA] Add category to study_sessions
-- Description: Sprint 8.5 (Offline Study-Log Categories). Adds a nullable
-- `category` column to `study_sessions` so a manually-logged offline session
-- (source = 'manual') can be tagged with what the student was doing. Exactly
-- five values for now: reading, writing_practice, lecture_viewing,
-- paper_solving, mock_test — enforced by CHECK, chosen deliberately narrow
-- (see blueprint.md Sprint 8.5 notes for the dropped "Revision/Recap" option).
-- Nullable, no default, no backfill — every pre-existing row simply has no
-- category, consistent with D-15 (never guess at historical data, established
-- in the Sprint 8.4 exam-date sprint). get_study_time_stats needs no change:
-- its SUM(duration_seconds) aggregation does not reference category (confirmed
-- via 00_DIAGNOSTIC's function-body dump).
-- Run 00_DIAGNOSTIC_confirm_no_category_column.sql first.

ALTER TABLE study_sessions
  ADD COLUMN category text
    CHECK (category IS NULL OR category IN (
      'reading', 'writing_practice', 'lecture_viewing', 'paper_solving', 'mock_test'
    ));
