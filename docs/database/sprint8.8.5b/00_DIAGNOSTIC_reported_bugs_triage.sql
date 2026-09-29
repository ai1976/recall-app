-- ============================================================================
-- Name: [DIAGNOSTIC] Reported-bugs triage (items 1, 2, 3, 4, 8) — READ ONLY
-- Description: Confirms the DB-side facts behind the 29/09/2026 bug/feature list
--   before any fix is designed. Every query is a SELECT; nothing is written.
--   Run each block separately in the Supabase SQL Editor and paste results back.
-- ============================================================================

-- ── Item 1 · Aarya Bapat — did her 3h offline log ever reach the DB? ─────────
-- Expect rows with source='manual'. Zero rows = the log never saved (category
-- picker never confirmed / timer discarded); rows present = display gap only.
SELECT id, started_at, ended_at, duration_seconds, session_date, source, category, created_at
FROM study_sessions
WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6'
ORDER BY created_at DESC
LIMIT 20;

-- Her activity-log rows (what the heatmap actually reads):
SELECT activity_type, activity_date, created_at
FROM user_activity_log
WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6'
ORDER BY activity_date DESC
LIMIT 20;

-- ── Item 1 · Are there ANY triggers/functions that write user_activity_log
--    from study_sessions? (catalog check, not code inference) ────────────────
SELECT trigger_name, event_object_table, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND (event_object_table = 'study_sessions' OR action_statement ILIKE '%user_activity_log%')
ORDER BY event_object_table;

-- ── Item 2 · Shriya Sundardm — what is actually in her My Study? ────────────
SELECT p.course_level AS profile_course_level,
       (SELECT array_agg(pc.*::text) FROM profile_courses pc WHERE pc.user_id = p.id) AS profile_courses_rows
FROM profiles p
WHERE p.id = 'c920165b-01a4-4509-af9a-9440f83884f2';

-- Enrollment rows by owner type (own vs. professor/other) — what get_my_cards keys off:
SELECT (f.user_id = e.user_id) AS is_own, e.status, COUNT(*) AS n
FROM my_cards_enrollment e
JOIN flashcards f ON f.id = e.flashcard_id
WHERE e.user_id = 'c920165b-01a4-4509-af9a-9440f83884f2'
GROUP BY 1, 2
ORDER BY 1, 2;

-- Which course/subject do those enrolled cards belong to?
SELECT COALESCE(s.name, f.custom_subject, 'Other') AS subject, s.course_level AS subject_course, COUNT(*) AS n
FROM my_cards_enrollment e
JOIN flashcards f ON f.id = e.flashcard_id
LEFT JOIN subjects s ON s.id = f.subject_id
WHERE e.user_id = 'c920165b-01a4-4509-af9a-9440f83884f2' AND e.status = 'active'
GROUP BY 1, 2
ORDER BY n DESC;

-- Same check for Rujuta (item 4 also changed course) — is her My Study similarly stale?
SELECT COALESCE(s.name, f.custom_subject, 'Other') AS subject, s.course_level AS subject_course, COUNT(*) AS n
FROM my_cards_enrollment e
JOIN flashcards f ON f.id = e.flashcard_id
LEFT JOIN subjects s ON s.id = f.subject_id
WHERE e.user_id = 'd4dc60d2-66af-4caf-bbff-6b160665addd' AND e.status = 'active'
GROUP BY 1, 2
ORDER BY n DESC;

-- ── Item 3 · Sairaj Kandhare — does an account already exist? ───────────────
-- Supabase signUp() returns an apparent success for an already-registered
-- email and sends NO mail (anti-enumeration). Check that first.
SELECT id, email, created_at, email_confirmed_at, confirmation_sent_at, last_sign_in_at,
       (SELECT COUNT(*) FROM auth.identities i WHERE i.user_id = u.id) AS identities
FROM auth.users u
WHERE lower(email) LIKE 'sai.kandhare%' OR lower(email) LIKE '%kandhare%';

-- ── Item 4 · Rujuta Bhatwadekar — recovery-link session history ─────────────
-- recovery_sent_at shows when the reset mails went out; last_sign_in_at shows
-- whether the link itself logged her in.
SELECT id, email, recovery_sent_at, last_sign_in_at, updated_at
FROM auth.users
WHERE id = 'd4dc60d2-66af-4caf-bbff-6b160665addd';

-- ── Item 8 · Professor ↔ batch access — what exists today? ──────────────────
-- Who can see batch reports now: get_my_batch_groups has two role branches.
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_my_batch_groups';

-- Existing batch groups and their members with a professor role:
SELECT g.id AS group_id, g.name, g.created_by, m.user_id, pr.full_name, pr.role, m.status
FROM study_groups g
JOIN study_group_members m ON m.group_id = g.id
JOIN profiles pr ON pr.id = m.user_id
WHERE g.is_batch_group = true AND pr.role = 'professor'
ORDER BY g.name;
