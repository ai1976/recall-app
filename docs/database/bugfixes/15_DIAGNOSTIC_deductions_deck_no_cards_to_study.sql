-- Name: [DIAGNOSTIC] Why "Deductions from Gross Total Income" showed "No flashcards to study" for TestOutlook
-- Description: Sprint 7.6 live-testing hit "No flashcards to study" when clicking directly into the
-- Income Tax -> Deductions from Gross Total Income deck (id 72837683-e562-48c3-b700-e8d8e28f2241) as
-- the TestOutlook student account, both with and without the new Question Type filter active — ruling
-- out the filter itself. Reading StudyMode.jsx's fetchFlashcards (the handler for /dashboard/study,
-- used by both the due-queue AND a direct deck click) found the likely mechanism: it applies the same
-- SRS-aware filter regardless of entry path -- `dueIds.has(c.id) || !reviewedIds.has(c.id)` -- so a
-- card that already has a `reviews` row but is NOT currently due (already graded today, scheduled for
-- a future date) is excluded even when the student explicitly clicked into that specific deck to study
-- it, not the due queue. Hypothesis: this deck's cards were graded during Sprint 7.5's live MCQ testing
-- (same deck, same account) earlier the same day, so their next_review_date is now in the future.
-- This query confirms or refutes that against live data -- do not treat the hypothesis as confirmed
-- until this returns.

-- 1. Find the TestOutlook account.
SELECT id, full_name, role, course_level
FROM profiles
WHERE full_name = 'TestOutlook';

-- 2. Find the deck and its flashcards (Income Tax / Deductions from Gross Total Income).
--    Uses the standard 5-grouping-column join, never fc.deck_id (always NULL, see CLAUDE.md).
WITH deck AS (
  SELECT fd.id, fd.user_id, fd.subject_id, fd.topic_id, fd.custom_subject, fd.custom_topic
  FROM flashcard_decks fd
  WHERE fd.id = '72837683-e562-48c3-b700-e8d8e28f2241'
)
SELECT fc.id AS flashcard_id, fc.question_type, fc.visibility, fc.created_at
FROM flashcards fc
JOIN deck d
  ON fc.user_id = d.user_id
 AND (fc.subject_id IS NOT DISTINCT FROM d.subject_id)
 AND (fc.topic_id IS NOT DISTINCT FROM d.topic_id)
 AND (fc.custom_subject IS NOT DISTINCT FROM d.custom_subject)
 AND (fc.custom_topic IS NOT DISTINCT FROM d.custom_topic)
ORDER BY fc.created_at;

-- 3. The actual test: for TestOutlook, what does this deck's reviews state look like, and is each
--    card excluded by the exact predicate StudyMode.jsx applies client-side (dueIds.has OR NOT reviewedIds.has)?
WITH deck AS (
  SELECT fd.id, fd.user_id, fd.subject_id, fd.topic_id, fd.custom_subject, fd.custom_topic
  FROM flashcard_decks fd
  WHERE fd.id = '72837683-e562-48c3-b700-e8d8e28f2241'
),
deck_cards AS (
  SELECT fc.id AS flashcard_id
  FROM flashcards fc
  JOIN deck d
    ON fc.user_id = d.user_id
   AND (fc.subject_id IS NOT DISTINCT FROM d.subject_id)
   AND (fc.topic_id IS NOT DISTINCT FROM d.topic_id)
   AND (fc.custom_subject IS NOT DISTINCT FROM d.custom_subject)
   AND (fc.custom_topic IS NOT DISTINCT FROM d.custom_topic)
)
SELECT
  dc.flashcard_id,
  r.status,
  r.next_review_date,
  r.skip_until,
  r.rung,
  (r.flashcard_id IS NOT NULL) AS has_review_row,
  (r.next_review_date <= CURRENT_DATE) AS naive_due_by_date_only
FROM deck_cards dc
LEFT JOIN reviews r
  ON r.flashcard_id = dc.flashcard_id
 AND r.user_id = (SELECT id FROM profiles WHERE full_name = 'TestOutlook')
ORDER BY dc.flashcard_id;

-- 4. Cross-check against the actual get_study_queue RPC (the real "is it due" authority --
--    query 3's naive_due_by_date_only is illustrative only, NOT the real predicate: get_study_queue
--    also applies status='active', skip_until, and course-match filters). Run as TestOutlook via
--    impersonation (SET LOCAL ROLE authenticated + request.jwt.claims, same technique as
--    docs/database/sprint7.5/02_TEST_verify_d10_role_gate.sql) since get_study_queue requires
--    auth.uid() = p_user_id (or admin).
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM profiles WHERE full_name = 'TestOutlook'), 'role', 'authenticated')::text,
  true);

SELECT flashcard_id, rung, next_review_date
FROM get_study_queue((SELECT id FROM profiles WHERE full_name = 'TestOutlook'))
WHERE flashcard_id IN (
  SELECT fc.id
  FROM flashcards fc
  JOIN flashcard_decks fd ON fd.id = '72837683-e562-48c3-b700-e8d8e28f2241'
   AND fc.user_id = fd.user_id
   AND (fc.subject_id IS NOT DISTINCT FROM fd.subject_id)
   AND (fc.topic_id IS NOT DISTINCT FROM fd.topic_id)
   AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
   AND (fc.custom_topic IS NOT DISTINCT FROM fd.custom_topic)
);

RESET ROLE;
ROLLBACK; -- read-only test; nothing to undo

-- Expected result if the hypothesis is correct: query 3 shows 3 rows, all WITH a reviews row
-- (has_review_row = true), all with next_review_date in the future (tomorrow+); query 4 (the real
-- due-queue) returns ZERO of these 3 flashcard_ids -- confirming every card is "reviewed but not
-- due", which is exactly the set StudyMode.jsx's client-side filter excludes when clicking directly
-- into this deck. If instead any card comes back with has_review_row = false (never reviewed) or a
-- past next_review_date, the hypothesis is wrong and needs a different explanation.

-- ============================================================================
-- ✅ CONFIRMED LIVE (13/09/2026). Query 3: all 3 of TestOutlook's visible cards
-- (00cbfbf7, 91d5a2f3, f84d137c -- the 4th, b269e9b9, is the professor's private
-- card the student can't even see) have status='active', has_review_row=true,
-- next_review_date in the future (09-14, 09-16, 09-20 -- today is 09-13). Query 4:
-- the real get_study_queue, filtered to these 3 ids, returned ZERO rows.
-- Root cause: this deck's cards were graded during Sprint 7.5's live MCQ testing
-- earlier the same day (same deck, same account -- it's the card Sprint 7.5 used
-- to test both the wrong-answer and correct-answer grading paths), so they're
-- scheduled forward and correctly excluded from "due." NOT a bug in Sprint 7.6,
-- NOT a bug in StudyMode.jsx's filter logic -- working exactly as designed.
-- Real UX gap, logged separately (see bugs.md): clicking a specific deck to study
-- it applies the SAME due/new-only filter as the due queue, so "this deck has 0
-- cards" and "you already reviewed everything in this deck today" render as the
-- identical generic "No flashcards to study" empty state, with no way to tell
-- them apart. Fixing that is a StudyMode.jsx change -- out of scope here.
-- ============================================================================
