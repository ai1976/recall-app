-- Name: [DIAGNOSTIC] Sprint 8.7.10 Step 0 - own-card enrollment migration control totals
-- Description: Run this BEFORE any migration/schema change for Sprint 8.7.10 (My Study Semantic
-- Cleanup). It measures how many own-authored flashcards fall into each backfill bucket under the
-- agreed rule: a `reviews` row is the only accepted evidence that an own card had a genuine study
-- relationship under the old (auto-enroll) design. Existing authoritative `reviews.status`
-- (active/suspended/mastered) is what gets carried into the new `my_cards_enrollment.status`,
-- NOT a blanket 'active'. Cards with no reviews row are never backfilled purely for being
-- authored. Read-only — no writes, no ROLLBACK needed, safe to run as-is.

-- ============================================================================
-- 1. Overall population buckets (totals across all users)
-- ============================================================================
WITH own_cards AS (
  SELECT
    f.id AS flashcard_id,
    f.user_id,
    r.status AS review_status,
    r.rung,
    r.next_review_date,
    (r.id IS NOT NULL) AS has_review,
    me.status AS existing_enrollment_status
  FROM public.flashcards f
  LEFT JOIN public.reviews r
    ON r.flashcard_id = f.id AND r.user_id = f.user_id
  LEFT JOIN public.my_cards_enrollment me
    ON me.flashcard_id = f.id AND me.user_id = f.user_id
  WHERE f.question_type IS DISTINCT FROM 'concept_card'  -- concept cards never enter SRS; exclude from population
)
SELECT
  COUNT(*) FILTER (WHERE has_review)                                   AS own_cards_with_reviews_row,
  COUNT(*) FILTER (WHERE NOT has_review)                                AS own_cards_without_reviews_row,
  COUNT(*) FILTER (WHERE has_review AND review_status = 'active')       AS reviews_status_active,
  COUNT(*) FILTER (WHERE has_review AND review_status = 'suspended')    AS reviews_status_suspended,
  COUNT(*) FILTER (WHERE has_review AND review_status = 'mastered')     AS reviews_status_mastered,
  COUNT(*) FILTER (WHERE has_review AND review_status NOT IN ('active','suspended','mastered')) AS reviews_status_other_unexpected,
  COUNT(*) FILTER (WHERE existing_enrollment_status = 'active')         AS already_has_active_enrollment_row,
  COUNT(*) FILTER (WHERE existing_enrollment_status = 'removed')        AS already_has_removed_enrollment_row,
  COUNT(*)                                                              AS total_own_cards_excl_concept
FROM own_cards;

-- ============================================================================
-- 2. The exact backfill target set: own cards WITH a reviews row that do NOT
--    already have an enrollment row (these are the ones the migration would INSERT)
-- ============================================================================
SELECT
  r.status AS reviews_status_to_carry_forward,
  COUNT(*) AS card_count
FROM public.flashcards f
JOIN public.reviews r
  ON r.flashcard_id = f.id AND r.user_id = f.user_id
LEFT JOIN public.my_cards_enrollment me
  ON me.flashcard_id = f.id AND me.user_id = f.user_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND me.id IS NULL  -- not already enrolled
GROUP BY r.status
ORDER BY card_count DESC;

-- ============================================================================
-- 3. Ambiguity check: own cards with a reviews row but status is NOT one of the
--    three known values (active/suspended/mastered). If this returns any rows,
--    STOP and report before migrating -- it means reviews.status has a value the
--    enrollment model doesn't have a mapping for yet.
-- ============================================================================
SELECT f.id AS flashcard_id, f.user_id, r.status, r.rung, r.next_review_date, r.created_at
FROM public.flashcards f
JOIN public.reviews r
  ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
  AND r.status NOT IN ('active', 'suspended', 'mastered');

-- ============================================================================
-- 4. Per-user breakdown (own cards with reviews vs without, top 30 users by volume)
-- ============================================================================
SELECT
  f.user_id,
  COUNT(*) FILTER (WHERE r.id IS NOT NULL) AS own_cards_with_reviews,
  COUNT(*) FILTER (WHERE r.id IS NULL)     AS own_cards_without_reviews,
  COUNT(*)                                 AS total_own_cards
FROM public.flashcards f
LEFT JOIN public.reviews r
  ON r.flashcard_id = f.id AND r.user_id = f.user_id
WHERE f.question_type IS DISTINCT FROM 'concept_card'
GROUP BY f.user_id
ORDER BY total_own_cards DESC
LIMIT 30;

-- ============================================================================
-- 5. Sanity check: any row in `reviews` for an own card where the paired
--    flashcard no longer exists, or user_id mismatch patterns (should be 0 --
--    reviews.flashcard_id has ON DELETE CASCADE, but confirming before we lean
--    on "reviews row exists" as the sole evidence source)
-- ============================================================================
SELECT COUNT(*) AS orphaned_reviews_rows
FROM public.reviews r
LEFT JOIN public.flashcards f ON f.id = r.flashcard_id
WHERE f.id IS NULL;
