-- Name: [FUNCTIONS] Featured Content Nomination & Approval RPCs
-- Description: Six SECURITY DEFINER RPCs implementing the two-step curation gate for
-- Phase 5 Sprint 3: professors/admins nominate their own already-public decks/notes; admins/
-- super_admins approve, reject, or unfeature. All six branch on p_content_type IN
-- ('deck','note') against flashcard_decks / notes. Featuring is only ever offered on
-- visibility='public' rows; the S2 CHECK constraint and the 10_SCHEMA auto-clear trigger are
-- the backstops if that invariant is ever violated mid-flow. These RPCs are ADDITIVE on top of
-- the deployed S2 is_featured_on_landing column/CHECK/trigger/get_featured_landing_content()
-- RPC — none of those S2 objects are modified here.
--
-- nominate_featured_content: caller must be professor/admin/super_admin AND (own the row OR
--   be admin/super_admin); row must be visibility='public'. Sets featured_nominated_by/at.
--   Does NOT set is_featured_on_landing. Idempotent (re-nominating just refreshes the
--   timestamp).
-- approve_featured_nomination: admin/super_admin only. Requires a pending nomination
--   (featured_nominated_at IS NOT NULL) and visibility='public'. Sets
--   is_featured_on_landing=true + featured_approved_by/at. Returns the resulting
--   is_featured_on_landing boolean so the caller can verify success even if the row went
--   non-public between page load and click (the CHECK/trigger would keep it false).
-- reject_featured_nomination: admin/super_admin only. Nulls all four nomination/approval
--   fields; leaves is_featured_on_landing=false.
-- unfeature_content: admin/super_admin only. Full removal — sets is_featured_on_landing=false
--   AND nulls all four nomination/approval fields, so an unfeatured item leaves BOTH the landing
--   and the Pending Nominations queue in one step. Functionally identical to
--   reject_featured_nomination; the two names are kept for UI/audit clarity (Live vs Pending).
--   Re-featuring requires an explicit fresh nomination by the creator/admin.
-- get_pending_featured_nominations / get_live_featured_content_admin: admin/super_admin only.
--   Each UNION ALLs decks + notes into one shape for the admin queues (card_count is NULL for
--   notes). ORDER BY is applied to the combined result, hence the explicit column aliases on
--   the first branch of each UNION.

CREATE OR REPLACE FUNCTION public.nominate_featured_content(
  p_content_type text,
  p_content_id   uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
  v_owner_id    uuid;
  v_visibility  text;
BEGIN
  IF p_content_type NOT IN ('deck', 'note') THEN
    RAISE EXCEPTION 'Invalid content_type: %', p_content_type;
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('professor', 'admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_content_type = 'deck' THEN
    SELECT user_id, visibility INTO v_owner_id, v_visibility
    FROM flashcard_decks WHERE id = p_content_id;
  ELSE
    SELECT user_id, visibility INTO v_owner_id, v_visibility
    FROM notes WHERE id = p_content_id;
  END IF;

  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'Content not found';
  END IF;

  IF v_visibility <> 'public' THEN
    RAISE EXCEPTION 'Content must be public to nominate for featuring';
  END IF;

  IF v_owner_id <> auth.uid() AND v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_content_type = 'deck' THEN
    UPDATE flashcard_decks
    SET featured_nominated_by = auth.uid(), featured_nominated_at = now()
    WHERE id = p_content_id;
  ELSE
    UPDATE notes
    SET featured_nominated_by = auth.uid(), featured_nominated_at = now()
    WHERE id = p_content_id;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.approve_featured_nomination(
  p_content_type text,
  p_content_id   uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role  text;
  v_nominated_at timestamptz;
  v_visibility   text;
  v_result       boolean;
BEGIN
  IF p_content_type NOT IN ('deck', 'note') THEN
    RAISE EXCEPTION 'Invalid content_type: %', p_content_type;
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_content_type = 'deck' THEN
    SELECT featured_nominated_at, visibility INTO v_nominated_at, v_visibility
    FROM flashcard_decks WHERE id = p_content_id;
  ELSE
    SELECT featured_nominated_at, visibility INTO v_nominated_at, v_visibility
    FROM notes WHERE id = p_content_id;
  END IF;

  IF v_nominated_at IS NULL THEN
    RAISE EXCEPTION 'No pending nomination found';
  END IF;

  IF v_visibility <> 'public' THEN
    RAISE EXCEPTION 'Content is no longer public';
  END IF;

  IF p_content_type = 'deck' THEN
    UPDATE flashcard_decks
    SET is_featured_on_landing = true,
        featured_approved_by = auth.uid(),
        featured_approved_at = now()
    WHERE id = p_content_id AND visibility = 'public'
    RETURNING is_featured_on_landing INTO v_result;
  ELSE
    UPDATE notes
    SET is_featured_on_landing = true,
        featured_approved_by = auth.uid(),
        featured_approved_at = now()
    WHERE id = p_content_id AND visibility = 'public'
    RETURNING is_featured_on_landing INTO v_result;
  END IF;

  RETURN COALESCE(v_result, false);
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_featured_nomination(
  p_content_type text,
  p_content_id   uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
BEGIN
  IF p_content_type NOT IN ('deck', 'note') THEN
    RAISE EXCEPTION 'Invalid content_type: %', p_content_type;
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_content_type = 'deck' THEN
    UPDATE flashcard_decks
    SET featured_nominated_by = NULL, featured_nominated_at = NULL,
        featured_approved_by = NULL, featured_approved_at = NULL
    WHERE id = p_content_id;
  ELSE
    UPDATE notes
    SET featured_nominated_by = NULL, featured_nominated_at = NULL,
        featured_approved_by = NULL, featured_approved_at = NULL
    WHERE id = p_content_id;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.unfeature_content(
  p_content_type text,
  p_content_id   uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
BEGIN
  IF p_content_type NOT IN ('deck', 'note') THEN
    RAISE EXCEPTION 'Invalid content_type: %', p_content_type;
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_content_type = 'deck' THEN
    UPDATE flashcard_decks
    SET is_featured_on_landing = false,
        featured_nominated_by = NULL, featured_nominated_at = NULL,
        featured_approved_by = NULL, featured_approved_at = NULL
    WHERE id = p_content_id;
  ELSE
    UPDATE notes
    SET is_featured_on_landing = false,
        featured_nominated_by = NULL, featured_nominated_at = NULL,
        featured_approved_by = NULL, featured_approved_at = NULL
    WHERE id = p_content_id;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_pending_featured_nominations()
RETURNS TABLE (
  content_type      text,
  content_id        uuid,
  title             text,
  subject           text,
  topic             text,
  card_count        integer,
  owner_name        text,
  nominated_by_name text,
  nominated_at      timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
BEGIN
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT
    'deck'::text                                            AS content_type,
    fd.id                                                    AS content_id,
    COALESCE(fd.name, fd.description, 'Untitled Study Set')  AS title,
    COALESCE(s.name, fd.custom_subject)                      AS subject,
    COALESCE(t.name, fd.custom_topic)                        AS topic,
    fd.card_count                                            AS card_count,
    owner.full_name                                          AS owner_name,
    nom.full_name                                             AS nominated_by_name,
    fd.featured_nominated_at                                 AS nominated_at
  FROM flashcard_decks fd
  LEFT JOIN subjects s ON s.id = fd.subject_id
  LEFT JOIN topics   t ON t.id = fd.topic_id
  LEFT JOIN profiles owner ON owner.id = fd.user_id
  LEFT JOIN profiles nom   ON nom.id = fd.featured_nominated_by
  WHERE fd.featured_nominated_at IS NOT NULL
    AND fd.is_featured_on_landing = false
    AND fd.visibility = 'public'

  UNION ALL

  SELECT
    'note'::text,
    nt.id,
    nt.title,
    COALESCE(s2.name, nt.custom_subject),
    COALESCE(t2.name, nt.custom_topic),
    NULL::integer,
    owner2.full_name,
    nom2.full_name,
    nt.featured_nominated_at
  FROM notes nt
  LEFT JOIN subjects s2 ON s2.id = nt.subject_id
  LEFT JOIN topics   t2 ON t2.id = nt.topic_id
  LEFT JOIN profiles owner2 ON owner2.id = nt.user_id
  LEFT JOIN profiles nom2   ON nom2.id = nt.featured_nominated_by
  WHERE nt.featured_nominated_at IS NOT NULL
    AND nt.is_featured_on_landing = false
    AND nt.visibility = 'public'

  ORDER BY nominated_at ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_live_featured_content_admin()
RETURNS TABLE (
  content_type      text,
  content_id        uuid,
  title             text,
  subject           text,
  topic             text,
  card_count        integer,
  owner_name        text,
  nominated_by_name text,
  nominated_at      timestamptz,
  approved_at       timestamptz,
  approved_by_name  text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
BEGIN
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN QUERY
  SELECT
    'deck'::text                                            AS content_type,
    fd.id                                                    AS content_id,
    COALESCE(fd.name, fd.description, 'Untitled Study Set')  AS title,
    COALESCE(s.name, fd.custom_subject)                      AS subject,
    COALESCE(t.name, fd.custom_topic)                        AS topic,
    fd.card_count                                            AS card_count,
    owner.full_name                                          AS owner_name,
    nom.full_name                                             AS nominated_by_name,
    fd.featured_nominated_at                                 AS nominated_at,
    fd.featured_approved_at                                  AS approved_at,
    appr.full_name                                           AS approved_by_name
  FROM flashcard_decks fd
  LEFT JOIN subjects s ON s.id = fd.subject_id
  LEFT JOIN topics   t ON t.id = fd.topic_id
  LEFT JOIN profiles owner ON owner.id = fd.user_id
  LEFT JOIN profiles nom   ON nom.id = fd.featured_nominated_by
  LEFT JOIN profiles appr  ON appr.id = fd.featured_approved_by
  WHERE fd.is_featured_on_landing = true

  UNION ALL

  SELECT
    'note'::text,
    nt.id,
    nt.title,
    COALESCE(s2.name, nt.custom_subject),
    COALESCE(t2.name, nt.custom_topic),
    NULL::integer,
    owner2.full_name,
    nom2.full_name,
    nt.featured_nominated_at,
    nt.featured_approved_at,
    appr2.full_name
  FROM notes nt
  LEFT JOIN subjects s2 ON s2.id = nt.subject_id
  LEFT JOIN topics   t2 ON t2.id = nt.topic_id
  LEFT JOIN profiles owner2 ON owner2.id = nt.user_id
  LEFT JOIN profiles nom2   ON nom2.id = nt.featured_nominated_by
  LEFT JOIN profiles appr2  ON appr2.id = nt.featured_approved_by
  WHERE nt.is_featured_on_landing = true

  ORDER BY approved_at DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.nominate_featured_content(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_featured_nomination(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_featured_nomination(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unfeature_content(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_featured_nominations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_featured_content_admin() TO authenticated;

NOTIFY pgrst, 'reload schema';
