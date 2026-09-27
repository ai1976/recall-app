-- Name: [DIAGNOSTIC] Sprint 8.8.4a - pre-migration control totals for the enrollment backfill widen
-- Description: Read-only. Run BEFORE 02_DATA_backfill_all_cards_enrollment.sql. Establishes the
-- baseline the post-migration checks (03_TEST) must move against. Reuses the EXACT genuine-review
-- predicate Sprint 8.7.10 settled on after its own correction (01_DATA + 08_CLEANUP):
--   genuine  := reviews.rung IS NOT NULL  OR  EXISTS (a review_events row for that user+card)
--   bare row := reviews.rung IS NULL  AND  NOT EXISTS (a review_events row)  -- skip_card/
--               suspend_card signature, correctly excluded in 8.7.10, stays excluded here.
-- The ONLY change from 8.7.10's predicate is removing the `f.user_id = r.user_id` (own-card-only)
-- restriction -- every other condition is byte-identical to what 08_CLEANUP proved out.

-- A. Qualifying (genuine) reviews rows with NO my_cards_enrollment row at all, split own/not-own,
--    with distinct-user counts. This is what 02_DATA is about to insert.
SELECT
  (f.user_id = r.user_id) AS is_own_card,
  COUNT(*) AS qualifying_rows_missing_enrollment,
  COUNT(DISTINCT r.user_id) AS distinct_users_affected
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND (
    r.rung IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id)
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.my_cards_enrollment e
    WHERE e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
  )
GROUP BY 1
ORDER BY 1;

-- B. Of the qualifying-but-missing set, how many are active+due right now vs suspended/not-yet-due?
--    (context only -- the backfill inserts for ALL of them regardless of current review_status,
--    since enrollment is membership, not scheduling state -- but this tells you how much of this
--    is "breaking students today" vs "would break them the next time this card comes due")
SELECT
  (f.user_id = r.user_id) AS is_own_card,
  r.status AS review_status,
  (r.status = 'active' AND r.next_review_date <= CURRENT_DATE) AS currently_due,
  COUNT(*) AS row_count
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND (
    r.rung IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id)
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.my_cards_enrollment e
    WHERE e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
  )
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- C. Existing enrollment rows that are NOT active, where the paired review is active+due right
--    now. These are pairs 02_DATA will correctly SKIP (it only inserts where no row exists at
--    all) -- reported here so nothing here is touched blind. A non-zero count here means: this
--    student deliberately Removed this card at some point, or something else set it inactive --
--    investigate those specific rows before deciding anything, per the "don't reactivate without
--    diagnosing" rule. This section performs no writes.
SELECT
  e.user_id, e.flashcard_id, e.status AS enrollment_status, e.added_at,
  r.status AS review_status, r.next_review_date, r.rung,
  (f.user_id = r.user_id) AS is_own_card
FROM public.my_cards_enrollment e
JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE e.status <> 'active'
  AND r.status = 'active'
  AND r.next_review_date <= CURRENT_DATE
ORDER BY e.added_at DESC;

-- D. Non-qualifying bare rows (skip_card/suspend_card signature), own vs not-own -- confirms what
--    will correctly stay excluded from the backfill (no change expected from this migration).
SELECT
  (f.user_id = r.user_id) AS is_own_card,
  COUNT(*) AS bare_row_count,
  COUNT(DISTINCT r.user_id) AS distinct_users
FROM public.reviews r
JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND r.rung IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.review_events re WHERE re.flashcard_id = r.flashcard_id AND re.user_id = r.user_id)
GROUP BY 1
ORDER BY 1;
