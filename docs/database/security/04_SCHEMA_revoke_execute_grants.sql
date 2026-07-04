-- Name: [SCHEMA] L5 — REVOKE EXECUTE per least-privilege classification
-- Description: Removes anon EXECUTE from all non-public functions, and both anon+authenticated from
-- internal/trigger functions. Classification derived from the frontend .rpc() grep + 03_DIAGNOSTIC.
-- App functions usually grant EXECUTE to PUBLIC (which anon inherits), so a bare "REVOKE FROM anon"
-- can no-op — hence the robust pattern: REVOKE FROM PUBLIC (+anon/authenticated) then GRANT back to
-- the roles that should keep it. is_admin/is_super_admin are NEVER touched (RLS depends on them).
-- Internal callers (triggers run as table owner; nested SECURITY DEFINER calls run as definer) are
-- unaffected by client-grant changes.
--
-- Run Block A first and review the full statement list; then run Block B to apply.
-- Idempotent-ish: re-running is safe (re-revokes/re-grants the same state).

-- Shared classification (edit here if the allowlist changes):
--   ANON allowlist (keep anon+authenticated): the 10 public-route functions + is_admin/is_super_admin
--   REVOKE BOTH (internal/trigger): 21 functions with zero frontend .rpc() calls

-- ============================================
-- BLOCK A — PREVIEW (read-only). Shows the action per function. Review before applying.
-- ============================================
WITH cls AS (
  SELECT
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) AS args,
    CASE
      WHEN p.proname IN (
        'get_public_educators','get_platform_stats','get_featured_landing_content',
        'get_public_deck_preview','get_public_note_preview','get_group_preview',
        'submit_educator_application','submit_institute_inquiry','submit_access_request',
        'get_anonymous_class_stats','is_admin','is_super_admin'
      ) THEN 'KEEP (anon allowlist / RLS)'
      WHEN p.proname IN (
        'award_badge','create_notification','cleanup_old_notifications','check_night_owl_badge',
        'auto_resolve_content_error_flags','notify_badge_earned','update_deck_card_count',
        'update_upvote_counts','fn_badge_check_flashcards','fn_badge_check_friendships',
        'fn_badge_check_new_profile','fn_badge_check_notes','fn_badge_check_reviews',
        'fn_badge_check_upvotes','fn_update_flashcards_counter','fn_update_friendships_counter',
        'fn_update_notes_counter','fn_update_reviews_counter','fn_update_upvotes_counter',
        'fn_create_profile_on_signup','fn_auto_enroll_batch_group'
      ) THEN 'REVOKE BOTH (internal)'
      ELSE 'REVOKE ANON (authenticated-only)'
    END AS action
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind IN ('f','p')
    AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
)
SELECT action, proname, args FROM cls ORDER BY action, proname;

-- ============================================
-- BLOCK B — APPLY.
-- ============================================
DO $$
DECLARE
  r RECORD;
  v_sig TEXT;
  v_allow  TEXT[] := ARRAY[
    'get_public_educators','get_platform_stats','get_featured_landing_content',
    'get_public_deck_preview','get_public_note_preview','get_group_preview',
    'submit_educator_application','submit_institute_inquiry','submit_access_request',
    'get_anonymous_class_stats','is_admin','is_super_admin'];
  v_both   TEXT[] := ARRAY[
    'award_badge','create_notification','cleanup_old_notifications','check_night_owl_badge',
    'auto_resolve_content_error_flags','notify_badge_earned','update_deck_card_count',
    'update_upvote_counts','fn_badge_check_flashcards','fn_badge_check_friendships',
    'fn_badge_check_new_profile','fn_badge_check_notes','fn_badge_check_reviews',
    'fn_badge_check_upvotes','fn_update_flashcards_counter','fn_update_friendships_counter',
    'fn_update_notes_counter','fn_update_reviews_counter','fn_update_upvotes_counter',
    'fn_create_profile_on_signup','fn_auto_enroll_batch_group'];
BEGIN
  FOR r IN
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind IN ('f','p')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
  LOOP
    v_sig := format('public.%I(%s)', r.proname, r.args);

    IF r.proname = ANY (v_allow) THEN
      CONTINUE;  -- keep as-is (anon allowlist / RLS helpers)

    ELSIF r.proname = ANY (v_both) THEN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated;', v_sig);
      EXECUTE format('GRANT  EXECUTE ON FUNCTION %s TO service_role;', v_sig);

    ELSE  -- authenticated-only
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon;', v_sig);
      EXECUTE format('GRANT  EXECUTE ON FUNCTION %s TO authenticated, service_role;', v_sig);
    END IF;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
