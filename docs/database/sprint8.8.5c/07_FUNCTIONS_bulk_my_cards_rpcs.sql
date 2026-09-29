-- Name: [FUNCTIONS] Sprint 8.8.5c - My Study bulk actions (Pause all / Resume all / Remove all)
-- Description: General-purpose feature, INDEPENDENT of course-change archival. Each RPC takes the card ids of one
--   Subject or Topic group and loops the EXISTING single-card functions inside one transaction, so per-card
--   behaviour is identical to the individual buttons (suspend_card / unsuspend_card / remove_from_my_cards,
--   each with its own IDOR guard; auth.uid() is still the caller inside these SECURITY DEFINER wrappers).
--   Only rows the single-card UI would also offer the action on are processed; everything else is counted as
--   skipped, so the frontend can show "N processed, M skipped":
--     bulk_pause_my_cards   : enrollment 'active' AND review row status 'active' (graded) - same as the Pause button
--     bulk_resume_my_cards  : enrollment 'active' AND review row status 'suspended'
--     bulk_remove_from_my_cards : enrollment 'active' (Remove is offered on New, Active and Paused cards)
--   Cap: 500 ids per call. Returns jsonb {requested, processed, skipped}.
--   Run on its own; independent of 03-06.

CREATE OR REPLACE FUNCTION public.bulk_pause_my_cards(p_user_id uuid, p_flashcard_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_ids uuid[]; v_id uuid; v_req int; v_done int := 0;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s My Study';
  END IF;
  IF p_flashcard_ids IS NULL OR array_length(p_flashcard_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'p_flashcard_ids must be a non-empty array';
  END IF;
  v_req := array_length(p_flashcard_ids, 1);
  IF v_req > 500 THEN RAISE EXCEPTION 'Too many cards in one request (max 500)'; END IF;

  SELECT COALESCE(array_agg(DISTINCT e.flashcard_id), '{}') INTO v_ids
  FROM public.my_cards_enrollment e
  JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
  WHERE e.user_id = p_user_id AND e.flashcard_id = ANY (p_flashcard_ids)
    AND e.status = 'active' AND r.status = 'active';

  FOREACH v_id IN ARRAY v_ids LOOP
    PERFORM public.suspend_card(p_user_id, v_id);
    v_done := v_done + 1;
  END LOOP;
  RETURN jsonb_build_object('requested', v_req, 'processed', v_done, 'skipped', v_req - v_done);
END;
$function$;

CREATE OR REPLACE FUNCTION public.bulk_resume_my_cards(p_user_id uuid, p_flashcard_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_ids uuid[]; v_id uuid; v_req int; v_done int := 0;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s My Study';
  END IF;
  IF p_flashcard_ids IS NULL OR array_length(p_flashcard_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'p_flashcard_ids must be a non-empty array';
  END IF;
  v_req := array_length(p_flashcard_ids, 1);
  IF v_req > 500 THEN RAISE EXCEPTION 'Too many cards in one request (max 500)'; END IF;

  SELECT COALESCE(array_agg(DISTINCT e.flashcard_id), '{}') INTO v_ids
  FROM public.my_cards_enrollment e
  JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
  WHERE e.user_id = p_user_id AND e.flashcard_id = ANY (p_flashcard_ids)
    AND e.status = 'active' AND r.status = 'suspended';

  FOREACH v_id IN ARRAY v_ids LOOP
    PERFORM public.unsuspend_card(p_user_id, v_id);
    v_done := v_done + 1;
  END LOOP;
  RETURN jsonb_build_object('requested', v_req, 'processed', v_done, 'skipped', v_req - v_done);
END;
$function$;

CREATE OR REPLACE FUNCTION public.bulk_remove_from_my_cards(p_user_id uuid, p_flashcard_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_ids uuid[]; v_id uuid; v_req int; v_done int := 0;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s My Study';
  END IF;
  IF p_flashcard_ids IS NULL OR array_length(p_flashcard_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'p_flashcard_ids must be a non-empty array';
  END IF;
  v_req := array_length(p_flashcard_ids, 1);
  IF v_req > 500 THEN RAISE EXCEPTION 'Too many cards in one request (max 500)'; END IF;

  SELECT COALESCE(array_agg(DISTINCT e.flashcard_id), '{}') INTO v_ids
  FROM public.my_cards_enrollment e
  WHERE e.user_id = p_user_id AND e.flashcard_id = ANY (p_flashcard_ids) AND e.status = 'active';

  FOREACH v_id IN ARRAY v_ids LOOP
    PERFORM public.remove_from_my_cards(p_user_id, v_id);
    v_done := v_done + 1;
  END LOOP;
  RETURN jsonb_build_object('requested', v_req, 'processed', v_done, 'skipped', v_req - v_done);
END;
$function$;

REVOKE ALL ON FUNCTION public.bulk_pause_my_cards(uuid, uuid[])          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.bulk_resume_my_cards(uuid, uuid[])         FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.bulk_remove_from_my_cards(uuid, uuid[])    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bulk_pause_my_cards(uuid, uuid[])       TO authenticated;
GRANT EXECUTE ON FUNCTION public.bulk_resume_my_cards(uuid, uuid[])      TO authenticated;
GRANT EXECUTE ON FUNCTION public.bulk_remove_from_my_cards(uuid, uuid[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
