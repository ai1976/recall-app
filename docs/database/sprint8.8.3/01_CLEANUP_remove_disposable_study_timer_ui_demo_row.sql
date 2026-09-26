-- Name: [CLEANUP] Remove disposable Sprint 8.8.3 study-timer UI-demo row
-- Description: During Sprint 8.8.3 (Desktop Left Rail Rebuild) live verification, a real
--   25-minute "reading" study_sessions row was created on purpose to demonstrate the
--   StudyTimerChip stop/category-picker UI in the new rail. It is disposable test data,
--   not a real study session, and should be removed so it doesn't skew this account's
--   study-time stats/leaderboard numbers.
--
--   study_sessions has NO delete RLS policy at all (the table is immutable by design —
--   confirmed live 16/09/2026, docs/database/sprint8.5/03_DIAGNOSTIC_confirm_study_sessions_immutable.sql,
--   also documented in DATABASE_SCHEMA.md's study_sessions section). This is exactly why the
--   app itself can never delete a row here, even for its own owner — it must be run directly
--   in the Supabase SQL Editor (connects as a role that bypasses RLS), not through the client.
--
-- Run Step 1 first and visually confirm it returns exactly the one row described above
-- before running Step 2. Do not run Step 2 if Step 1 returns more than one row, or a
-- duration_seconds that isn't 1500 (25 minutes) — widen/narrow the WHERE clause instead of
-- deleting blind.

-- ============================================================
-- STEP 1 — [DIAGNOSTIC] Confirm the exact disposable row
-- ============================================================
select
  ss.id,
  ss.user_id,
  p.email,
  ss.category,
  ss.source,
  ss.duration_seconds,
  ss.session_date,
  ss.started_at,
  ss.ended_at,
  ss.created_at
from study_sessions ss
join profiles p on p.id = ss.user_id
where p.email = 'ai@moreclassescommerce.com'
  and ss.source = 'manual'
  and ss.category = 'reading'
  and ss.duration_seconds = 1500
  and ss.created_at >= now() - interval '4 hours';

-- ============================================================
-- STEP 2 — [CLEANUP] Delete the confirmed row (run only after Step 1 checks out)
-- ============================================================
delete from study_sessions ss
using profiles p
where p.id = ss.user_id
  and p.email = 'ai@moreclassescommerce.com'
  and ss.source = 'manual'
  and ss.category = 'reading'
  and ss.duration_seconds = 1500
  and ss.created_at >= now() - interval '4 hours';

-- ============================================================
-- STEP 3 — [TEST] Verify zero rows remain matching the disposable-row criteria
-- ============================================================
select count(*) as remaining_disposable_rows
from study_sessions ss
join profiles p on p.id = ss.user_id
where p.email = 'ai@moreclassescommerce.com'
  and ss.source = 'manual'
  and ss.category = 'reading'
  and ss.duration_seconds = 1500
  and ss.created_at >= now() - interval '4 hours';
-- Expected: remaining_disposable_rows = 0
