-- Name: [DIAGNOSTIC] Review-save "Failed to save progress" — Sarang Gore report (26/09/2026)
-- Description: Investigates a student report that grading a card (tapping Easy/Medium/Hard in
-- Study Mode) throws "Failed to save progress" (StudyMode.jsx's generic catch-all toast around
-- the apply_review RPC call). Student: Sarang Gore, uuid e34acf2c-883d-41fa-a0e3-1d4a6704725e.
-- Card shown in the failing screenshot: front_text starting "SA 530 deals with", subject
-- "Auditing & Ethics", topic "Audit Evidence".
--
-- Context: apply_review gained two new RAISE EXCEPTION guards in Sprint 8.7.10 (25/09/2026,
-- one day before this report) — an active-my_cards_enrollment requirement and a not-suspended
-- check. Per code review, get_my_cards (the ONLY source StudyMode.jsx populates its flashcards
-- list from) already requires the exact same active-enrollment row apply_review now checks, so
-- a card that reached the screen should already satisfy apply_review's guard — but this must be
-- confirmed against the LIVE function bodies and LIVE data, not assumed from the docs/ SQL files
-- (per CLAUDE.md: absence of a mismatch is never confirmed by reading code alone).
--
-- Run sections 1-5 together (all read-only, safe as one submission). Run Section 6 (the live
-- repro call) as ITS OWN separate submission — it is wrapped in BEGIN/ROLLBACK and touches no
-- durable data, but per project convention a submission with a ROLLBACK should never be combined
-- with anything else.
--
-- Paste back the full output of every section — especially Section 6's exact error text/code,
-- which is the single most direct signal of the true root cause.

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SECTION 1 — Confirm the LIVE function bodies (Step 0 per project convention).
-- Compares against docs/database/sprint8.7.10/03_FUNCTIONS_apply_review_enrollment_guard.sql,
-- 02_FUNCTIONS_get_my_cards_v2.sql, and docs/database/sprint8.7.8e/01_FUNCTIONS_get_study_queue_
-- payload_parity.sql — confirms no undocumented hotfix has drifted from what's on disk.
-- ═══════════════════════════════════════════════════════════════════════════════════════
SELECT p.proname, pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('apply_review', 'get_my_cards', 'get_study_queue', 'srs_interval_for_rung')
ORDER BY p.proname;

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SECTION 2 — Identify the exact card(s) from the screenshot.
-- ═══════════════════════════════════════════════════════════════════════════════════════
SELECT f.id, f.user_id AS card_owner, f.question_type, f.front_text, f.visibility,
       f.subject_id, s.name AS subject_name, f.topic_id, t.name AS topic_name,
       f.target_course, f.created_at
FROM public.flashcards f
LEFT JOIN public.subjects s ON s.id = f.subject_id
LEFT JOIN public.topics   t ON t.id = f.topic_id
WHERE f.front_text ILIKE '%SA 530%'
ORDER BY f.created_at;

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SECTION 3 — Sarang's full due-queue audit: for every card get_study_queue would currently
-- hand him, show its enrollment status, review status/rung, and whether the SRS curve has an
-- interval defined for its current and next rung (a missing curve row would make
-- next_review_date NULL, which is a plausible silent-INSERT/UPDATE-failure root cause if
-- reviews.next_review_date is NOT NULL).
-- ═══════════════════════════════════════════════════════════════════════════════════════
WITH sarang AS (
  SELECT 'e34acf2c-883d-41fa-a0e3-1d4a6704725e'::uuid AS uid
),
today AS (
  SELECT (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date AS d
  FROM public.profiles p, sarang WHERE p.id = sarang.uid
)
SELECT
  r.flashcard_id,
  f.front_text,
  f.user_id AS card_owner,
  (f.user_id = r.user_id) AS is_own_card,
  f.question_type,
  r.status AS review_status,
  r.rung AS cur_rung,
  r.next_review_date,
  r.skip_until,
  e.status AS enrollment_status,
  e.added_at AS enrollment_added_at,
  (e.id IS NULL) AS enrollment_row_missing,
  cur_curve.interval_days AS interval_for_cur_rung,
  next_curve.interval_days AS interval_for_next_rung
FROM sarang
CROSS JOIN today
JOIN public.reviews r ON r.user_id = sarang.uid
JOIN public.flashcards f ON f.id = r.flashcard_id
LEFT JOIN public.my_cards_enrollment e
  ON e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
LEFT JOIN public.srs_ladder_curves cur_curve
  ON cur_curve.question_type = COALESCE(f.question_type, 'flashcard') AND cur_curve.rung_index = r.rung
LEFT JOIN public.srs_ladder_curves next_curve
  ON next_curve.question_type = COALESCE(f.question_type, 'flashcard') AND next_curve.rung_index = r.rung + 1
WHERE r.status = 'active'
  AND r.next_review_date <= today.d
  AND (r.skip_until IS NULL OR r.skip_until <= today.d)
ORDER BY is_own_card, enrollment_status NULLS FIRST, r.flashcard_id;

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SECTION 4 — Platform-wide impact scope. If this is bigger than one student, it needs to be
-- fixed before more students hit it. For every currently-due reviews row (what get_study_queue
-- would return to SOMEONE), check whether an active my_cards_enrollment row actually exists.
-- ═══════════════════════════════════════════════════════════════════════════════════════
SELECT
  (f.user_id = r.user_id) AS is_own_card,
  COUNT(*) AS due_review_rows,
  COUNT(*) FILTER (WHERE e.id IS NULL) AS enrollment_row_missing,
  COUNT(*) FILTER (WHERE e.id IS NOT NULL AND e.status <> 'active') AS enrollment_row_inactive,
  COUNT(DISTINCT r.user_id) FILTER (WHERE e.id IS NULL OR e.status <> 'active') AS distinct_students_affected
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
LEFT JOIN public.my_cards_enrollment e
  ON e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
WHERE r.status = 'active'
  AND r.next_review_date <= CURRENT_DATE
GROUP BY 1
ORDER BY 1;

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SECTION 5 — Catalog-verify the actual constraints on reviews/review_events (never assume
-- from the docs which columns are NOT NULL or CHECK-constrained).
-- ═══════════════════════════════════════════════════════════════════════════════════════
SELECT table_name, column_name, is_nullable, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('reviews', 'review_events')
ORDER BY table_name, ordinal_position;

SELECT conname, conrelid::regclass AS table_name, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('public.reviews'::regclass, 'public.review_events'::regclass)
ORDER BY table_name, conname;

-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SECTION 6 — RUN THIS SECTION ALONE, AS ITS OWN SUBMISSION.
-- Live repro: actually calls apply_review as Sarang, for one of his real due cards (from
-- Section 3's output — replace <FLASHCARD_ID_HERE> with a real flashcard_id from that result,
-- ideally the SA 530 card's id from Section 2), inside a transaction that is always rolled
-- back. This captures the EXACT error Postgres raises right now, with zero durable side
-- effects either way (success or failure). Simulates Sarang's JWT so apply_review's
-- auth.uid()-based guards evaluate the same way they do for his real session.
-- ═══════════════════════════════════════════════════════════════════════════════════════
BEGIN;

SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claims = '{"sub":"e34acf2c-883d-41fa-a0e3-1d4a6704725e","role":"authenticated"}';
SET LOCAL request.jwt.claim.sub = 'e34acf2c-883d-41fa-a0e3-1d4a6704725e';

SELECT auth.uid(); -- sanity check: must print e34acf2c-883d-41fa-a0e3-1d4a6704725e, not NULL

SELECT * FROM public.apply_review(
  p_user_id      => 'e34acf2c-883d-41fa-a0e3-1d4a6704725e'::uuid,
  p_flashcard_id => '<FLASHCARD_ID_HERE>'::uuid,
  p_rating       => 'medium',
  p_is_correct   => NULL,
  p_source       => 'review_session',
  p_selected_answer => NULL
);

ROLLBACK;
