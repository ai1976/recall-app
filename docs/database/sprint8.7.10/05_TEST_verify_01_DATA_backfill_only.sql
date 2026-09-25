-- Name: [TEST] Sprint 8.7.10 - verify 01_DATA backfill in isolation (pre-02/03 deploy)
-- Description: Read-only. Confirms the backfill that already ran landed exactly the expected
-- population and touched nothing else, BEFORE any function changes (02/03) are deployed. No RLS
-- impersonation needed -- these are direct table reads, not calls through get_my_cards/
-- apply_review.

-- 1. Exactly 1187 own-authored cards now have an active enrollment row, split 908/279 by the
--    underlying (untouched) reviews.status
SELECT
  COUNT(*) AS total_backfilled,
  COUNT(*) FILTER (WHERE r.status = 'active')    AS backfilled_review_active,
  COUNT(*) FILTER (WHERE r.status = 'suspended') AS backfilled_review_suspended,
  COUNT(*) FILTER (WHERE r.status NOT IN ('active','suspended')) AS backfilled_review_other_unexpected
FROM public.my_cards_enrollment me
JOIN public.flashcards f ON f.id = me.flashcard_id AND f.user_id = me.user_id
JOIN public.reviews r ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE me.status = 'active';
-- Expect: total=1187, active=908, suspended=279, other=0

-- 2. All 1187 enrollment rows are 'active' status (never 'removed') -- backfill never writes removed
SELECT COUNT(*) AS backfilled_rows_not_active
FROM public.my_cards_enrollment me
JOIN public.flashcards f ON f.id = me.flashcard_id AND f.user_id = me.user_id
WHERE me.status <> 'active'
  AND EXISTS (SELECT 1 FROM public.reviews r WHERE r.flashcard_id = f.id AND r.user_id = f.user_id);
-- Expect: 0

-- 3. The 279 suspended reviews rows are still suspended (not resumed by the backfill)
SELECT COUNT(*) AS still_suspended
FROM public.reviews r
JOIN public.my_cards_enrollment me ON me.flashcard_id = r.flashcard_id AND me.user_id = r.user_id
WHERE r.status = 'suspended' AND me.status = 'active';
-- Expect: 279

-- 4. The 908 active reviews rows are still active
SELECT COUNT(*) AS still_active
FROM public.reviews r
JOIN public.my_cards_enrollment me ON me.flashcard_id = r.flashcard_id AND me.user_id = r.user_id
WHERE r.status = 'active' AND me.status = 'active';
-- Expect: 908

-- 5. The 1618 never-reviewed own cards remain unenrolled
SELECT COUNT(*) AS never_reviewed_and_unenrolled
FROM public.flashcards f
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.flashcard_id = f.id AND r.user_id = f.user_id)
  AND NOT EXISTS (SELECT 1 FROM public.my_cards_enrollment me WHERE me.flashcard_id = f.id AND me.user_id = f.user_id);
-- Expect: 1618

-- 6. No SRS history field was touched by the backfill -- spot-check: every reviews row's
--    updated/last_reviewed_at predates the backfill run (adjust the timestamp below to shortly
--    before you ran 01_DATA if you know it; otherwise this at least confirms nothing was reviewed
--    "just now" as a side effect)
SELECT COUNT(*) AS reviews_rows_touched_in_last_hour
FROM public.reviews
WHERE last_reviewed_at >= now() - interval '1 hour';
-- Expect: 0 (or only rows YOU genuinely reviewed by hand in the last hour, if any -- eyeball this one)

-- 7. rung/next_review_date sanity -- confirm no NULL rung/next_review_date crept in among the
--    backfilled population (would indicate the backfill somehow inserted into reviews, which it
--    must not have -- it only ever inserts into my_cards_enrollment)
SELECT COUNT(*) AS backfilled_cards_with_null_srs_fields
FROM public.my_cards_enrollment me
JOIN public.reviews r ON r.flashcard_id = me.flashcard_id AND r.user_id = me.user_id
WHERE me.status = 'active' AND (r.rung IS NULL OR r.next_review_date IS NULL);
-- Expect: 0 (every one of these 1187 already had a real reviews row before the backfill touched
-- anything, so rung/next_review_date should already be populated exactly as they were)
