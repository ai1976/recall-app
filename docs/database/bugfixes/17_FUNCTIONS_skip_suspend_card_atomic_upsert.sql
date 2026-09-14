-- Name: [FUNCTIONS] skip_card / suspend_card — atomic upsert, closes the 23505 race condition
-- Description: Reproduced live 14/09/2026 (see 16_DIAGNOSTIC): "Skip 24hr" on a never-reviewed card
-- threw `23505 duplicate key value violates reviews_user_flashcard_unique`. Root cause: both
-- functions write `reviews` via a non-atomic `UPDATE ...; IF NOT FOUND THEN INSERT ...` (TOCTOU) —
-- two near-simultaneous calls for the same (user_id, flashcard_id) with no existing row can both see
-- "NOT FOUND" on their own UPDATE and both attempt the INSERT; the second violates the unique
-- constraint. StudyMode.jsx's 5 "Skip 24hr" buttons have no in-flight guard (no `disabled` while the
-- RPC call is pending), so a fast double-click/double-tap on a brand-new card reliably reproduces
-- this. Confirmed NOT a frontend logic bug — StudyMode.jsx's `handleSkip` already calls this single
-- RPC once per click; the race lives entirely in the RPC's non-atomic write.
--
-- Fix: replace the UPDATE-then-conditional-INSERT with a single atomic
-- `INSERT ... ON CONFLICT (user_id, flashcard_id) DO UPDATE SET ...` — Postgres resolves the
-- conflict inside one statement, so two concurrent calls can no longer both observe "no row" and
-- both attempt to create one; the loser's INSERT becomes a no-op UPDATE instead of an error.
-- The IDOR guard, timezone logic, and search_path are otherwise reproduced verbatim from the live
-- body (confirmed via 16_DIAGNOSTIC before this migration ran — do not deploy this file without
-- first confirming the live body matches, in case an undocumented later change exists).
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

  -- Atomic upsert — closes the race: a concurrent duplicate call now resolves as an UPDATE,
  -- never a failed INSERT.
  INSERT INTO reviews (user_id, flashcard_id, quality, interval, repetition, easiness, next_review_date, skip_until, status)
  VALUES (p_user_id, p_flashcard_id, 0, 0, 0, 2.5, CURRENT_DATE, v_tomorrow, 'active')
  ON CONFLICT (user_id, flashcard_id)
  DO UPDATE SET skip_until = v_tomorrow;
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

  -- Atomic upsert — same race fixed as skip_card above.
  INSERT INTO reviews (user_id, flashcard_id, quality, interval, repetition, easiness, next_review_date, status)
  VALUES (p_user_id, p_flashcard_id, 0, 0, 0, 2.5, CURRENT_DATE, 'suspended')
  ON CONFLICT (user_id, flashcard_id)
  DO UPDATE SET status = 'suspended', skip_until = NULL;
END;
$function$;
