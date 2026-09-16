-- [CLEANUP] Remove the one real test row from 05_TEST's case-2 verification
-- Description: 05_TEST's case-2 insert (proving a valid categorized manual
-- session still logs correctly) was deliberately run without a wrapping
-- BEGIN/ROLLBACK so its own result could be seen cleanly — it left one real
-- row in study_sessions. Filtered tightly (TestOutlook's user_id, the exact
-- source/category/duration used, and a 10-minute recency window) so this can
-- only ever match that one row, never a real student's data. Preview first,
-- confirm exactly 1 row, then delete.

-- Preview — expect exactly 1 row
SELECT id, user_id, category, source, duration_seconds, created_at
FROM public.study_sessions
WHERE user_id = (SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com')
  AND source = 'manual'
  AND category = 'lecture_viewing'
  AND duration_seconds = 600
  AND created_at >= now() - interval '15 minutes';

-- Delete — run only after confirming the preview above returned exactly 1 row
DELETE FROM public.study_sessions
WHERE user_id = (SELECT id FROM public.profiles WHERE email = 'anandmore@outlook.com')
  AND source = 'manual'
  AND category = 'lecture_viewing'
  AND duration_seconds = 600
  AND created_at >= now() - interval '15 minutes';
