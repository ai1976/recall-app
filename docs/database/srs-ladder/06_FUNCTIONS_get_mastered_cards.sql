-- Name: [FUNCTIONS] SRS Ladder Epic — Phase 3 support: get_mastered_cards
--
-- Description:
--   Phase 3 read RPC for the "Mastered Items" list (so cards that graduate to
--   status='mastered' — and leave the daily queue — never silently vanish).
--   Deliberately mirrors get_suspended_cards (docs/database/security/08) exactly:
--   same shape, same L5 self-only IDOR guard, same SECURITY DEFINER + pinned
--   search_path. Adds `mastered_at` (= last_reviewed_at, the moment of graduation)
--   and `next_review_date` so the UI can show when the card is next scheduled.
--
--   Run this as its own Supabase SQL Editor submission (it COMMITs) BEFORE the
--   Phase 3 frontend is pushed. Pure CREATE OR REPLACE.

CREATE OR REPLACE FUNCTION public.get_mastered_cards(p_user_id uuid)
 RETURNS TABLE (
   review_id        uuid,
   flashcard_id     uuid,
   front_text       text,
   back_text        text,
   subject_name     text,
   topic_name       text,
   rung             smallint,
   next_review_date date,
   mastered_at      timestamptz
 )
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;

  RETURN QUERY
  SELECT r.id, r.flashcard_id, f.front_text, f.back_text,
         COALESCE(s.name, f.custom_subject),
         COALESCE(t.name, f.custom_topic),
         r.rung,
         r.next_review_date,
         r.last_reviewed_at
  FROM reviews r
  JOIN flashcards f ON f.id = r.flashcard_id
  LEFT JOIN subjects s ON s.id = f.subject_id
  LEFT JOIN topics   t ON t.id = f.topic_id
  WHERE r.user_id = p_user_id
    AND r.status = 'mastered'
  ORDER BY COALESCE(s.name, f.custom_subject, 'ZZZ'), f.front_text;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_mastered_cards(uuid) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_mastered_cards(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_mastered_cards(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
