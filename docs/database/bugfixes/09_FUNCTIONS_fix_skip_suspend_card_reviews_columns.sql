-- Name: [FUNCTIONS] Fix skip_card + suspend_card reviews column names
-- Description: 08_DIAGNOSTIC confirmed the reviews table uses `easiness` (double precision) and
-- `repetition` (integer) — NOT `easiness_factor` / `repetitions`. Both functions' `IF NOT FOUND
-- THEN INSERT` branch (first-ever skip/suspend of a card with no review row) named the wrong columns
-- and threw 42703. Fixed: `repetitions`->`repetition`, `easiness_factor`->`easiness`. Also aligned
-- `next_review_date` to `CURRENT_DATE` (it's a date column; the branch previously passed NOW()) to
-- match skip_topic_cards. Everything else — the L5 IDOR guard, timezone logic, search_path — is
-- reproduced verbatim from the live bodies (08 Block 2). Same class of bug fixed in
-- skip_topic_cards/suspend_topic_cards on Apr 4, 2026.
--
-- Signatures unchanged -> safe in-place CREATE OR REPLACE, no PostgREST reload.

CREATE OR REPLACE FUNCTION public.skip_card(p_user_id uuid, p_flashcard_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_user_tz TEXT;
  v_tomorrow DATE;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s review state';
  END IF;

  -- Get user's timezone
  SELECT COALESCE(timezone, 'Asia/Kolkata')
  INTO v_user_tz
  FROM profiles
  WHERE id = p_user_id;

  -- Calculate tomorrow in user's local timezone
  v_tomorrow := (NOW() AT TIME ZONE v_user_tz)::DATE + INTERVAL '1 day';

  -- Update the review record
  UPDATE reviews
  SET skip_until = v_tomorrow
  WHERE user_id = p_user_id
    AND flashcard_id = p_flashcard_id;

  -- If no review record exists, create one with skip (corrected columns: easiness / repetition)
  IF NOT FOUND THEN
    INSERT INTO reviews (user_id, flashcard_id, quality, interval, repetition, easiness, next_review_date, skip_until, status)
    VALUES (p_user_id, p_flashcard_id, 0, 0, 0, 2.5, CURRENT_DATE, v_tomorrow, 'active');
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.suspend_card(p_user_id uuid, p_flashcard_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s review state';
  END IF;

  -- Update existing review to suspended
  UPDATE reviews
  SET status = 'suspended',
      skip_until = NULL
  WHERE user_id = p_user_id
    AND flashcard_id = p_flashcard_id;

  -- If no review record exists, create one as suspended (corrected columns: easiness / repetition)
  IF NOT FOUND THEN
    INSERT INTO reviews (user_id, flashcard_id, quality, interval, repetition, easiness, next_review_date, status)
    VALUES (p_user_id, p_flashcard_id, 0, 0, 0, 2.5, CURRENT_DATE, 'suspended');
  END IF;
END;
$function$;
