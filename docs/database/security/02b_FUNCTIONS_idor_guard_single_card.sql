-- Name: [FUNCTIONS] L5 IDOR guard on single-card scheduling RPCs
-- Description: Same IDOR fix as 02_FUNCTIONS, for skip_card / suspend_card / reset_card. Each took
-- p_user_id and wrote to reviews without checking it equals the caller. Adds the hard-block guard
-- (owner or admin only). Bodies reproduced VERBATIM from 03_DIAGNOSTIC Block 2 (live), with the
-- guard inserted right after BEGIN. search_path kept as the live 'public','extensions'.
--
-- ⚠️ KNOWN LATENT BUG (NOT fixed here — flagged for a separate, verified pass): skip_card and
-- suspend_card's `IF NOT FOUND` INSERT branch writes columns `easiness_factor` and `repetitions`,
-- but the reviews table uses `easiness` / `repetition` (per the Apr 4 bug fix + CLAUDE.md). That
-- branch (first-ever action on a card with no review row) likely errors 42703. Reproduced as-is to
-- keep this change guard-only; fixing it needs a reviews-column diagnostic + its own test.
--
-- Signatures unchanged -> safe in-place CREATE OR REPLACE, no PostgREST reload.

CREATE OR REPLACE FUNCTION public.reset_card(p_user_id uuid, p_flashcard_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s review state';
  END IF;

  DELETE FROM reviews
  WHERE user_id = p_user_id
    AND flashcard_id = p_flashcard_id;
END;
$function$;

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

  -- If no review record exists, create one with skip
  IF NOT FOUND THEN
    INSERT INTO reviews (user_id, flashcard_id, quality, interval, repetitions, easiness_factor, next_review_date, skip_until, status)
    VALUES (p_user_id, p_flashcard_id, 0, 0, 0, 2.5, NOW(), v_tomorrow, 'active');
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

  -- If no review record exists, create one as suspended
  IF NOT FOUND THEN
    INSERT INTO reviews (user_id, flashcard_id, quality, interval, repetitions, easiness_factor, next_review_date, status)
    VALUES (p_user_id, p_flashcard_id, 0, 0, 0, 2.5, NOW(), 'suspended');
  END IF;
END;
$function$;
