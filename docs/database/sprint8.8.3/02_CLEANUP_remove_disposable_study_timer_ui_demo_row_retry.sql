-- Name: [CLEANUP] Remove disposable Sprint 8.8.3 study-timer UI-demo row (retry)
-- Description: 01_CLEANUP_remove_disposable_study_timer_ui_demo_row.sql's Step 1 found zero
--   rows — its `duration_seconds = 1500` filter was too exact. The disposable row was created
--   by fast-forwarding a localStorage timestamp to "25 minutes ago" and then stopping the
--   timer for real, so the stored duration is 1500 PLUS however many seconds actually passed
--   between setting that timestamp and clicking Stop — not exactly 1500. This version browses
--   by a wide window/range instead of an exact match, so you can identify the real row by eye
--   and delete it by its own id (safest — no risk of a range match catching a different row).
--
--   Same reason as before: study_sessions has no delete RLS policy (immutable by design,
--   DATABASE_SCHEMA.md), so this must run in the Supabase SQL Editor, not through the app.
--
-- Run Step 1. Look for the one row with category = 'reading', source = 'manual', and a
-- duration a little over 25 minutes (roughly 1500-1600 seconds). Copy its `id` value.
-- Paste that id into Step 2's WHERE clause (replace <PASTE_ID_HERE>) before running it.
-- Do not run Step 2 with the placeholder still in it — it will match zero rows harmlessly,
-- but the point is to delete the ONE row you actually identified, not to guess a range.

-- ============================================================
-- STEP 1 — [DIAGNOSTIC] Browse this account's recent manual sessions
-- ============================================================
select
  ss.id,
  ss.category,
  ss.source,
  ss.duration_seconds,
  round(ss.duration_seconds / 60.0, 1) as duration_minutes,
  ss.session_date,
  ss.started_at,
  ss.ended_at,
  ss.created_at
from study_sessions ss
join profiles p on p.id = ss.user_id
where p.email = 'ai@moreclassescommerce.com'
  and ss.source = 'manual'
  and ss.created_at >= now() - interval '2 days'
order by ss.created_at desc;

-- ============================================================
-- STEP 2 — [CLEANUP] Delete the one row you identified in Step 1, by its id
-- ============================================================
delete from study_sessions
where id = '<PASTE_ID_HERE>';

-- ============================================================
-- STEP 3 — [TEST] Verify that id no longer exists
-- ============================================================
select count(*) as remaining
from study_sessions
where id = '<PASTE_ID_HERE>';
-- Expected: remaining = 0
