-- [FUNCTIONS] admin_delete_user_data: detach upload-batch provenance so user deletion cannot be blocked (Sprint 8.8.5b4, D-48)
-- Description: Found by test 09 (U4) and confirmed by 12 diagnostic (30/09/2026): flashcard_batch_provenance.created_by has a
--   foreign key to profiles(id) with NO delete rule, so deleting the profile fails for any user who created an upload batch
--   (today: 2 students with 5 rows, 1 professor with 166 rows). This was already true of the original function - it just
--   never showed because the ten students deleted so far owned no provenance rows. It is the ONLY blocking link: every
--   other foreign key to profiles cascades or sets null (12 block 1).
--   Fix: before the profile row is removed, created_by is set to NULL on the user's provenance rows (the column is
--   nullable), which keeps the batch-source history and removes the link. The number of detached rows is recorded in the
--   audit entry. Everything else is unchanged from 08 (guards, own audit entry written first, same deletes).
--   Not changed, recorded: deleting a profile also CASCADE-deletes study groups the user created (study_groups.created_by)
--   and their memberships, and content flags they raised - existing behaviour, relevant if a professor is ever deleted.
-- Rollback: 16 (restores the 08 definition). Test: rerun 09 (U4) and 11 (T7).

CREATE OR REPLACE FUNCTION public.admin_delete_user_data(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_denial  text;
  v_name    text;
  v_email   text;
  v_role    text;
  v_notes   integer;
  v_cards   integer;
  v_detached integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only super_admin can delete user data';
  END IF;

  -- Never yourself, never an admin / super admin account (demote first with admin_change_role).
  v_denial := public.admin_user_action_denial(auth.uid(), p_user_id);
  IF v_denial IS NOT NULL THEN
    RAISE EXCEPTION 'Access denied: %', v_denial USING ERRCODE = '42501';
  END IF;

  SELECT full_name, email, role INTO v_name, v_email, v_role FROM profiles WHERE id = p_user_id;
  SELECT count(*) INTO v_notes FROM notes WHERE user_id = p_user_id;
  SELECT count(*) INTO v_cards FROM flashcards WHERE user_id = p_user_id;
  SELECT count(*) INTO v_detached FROM flashcard_batch_provenance WHERE created_by = p_user_id;

  -- Audit FIRST, while the profile still exists (the foreign key nulls target_user_id afterwards, as before).
  INSERT INTO public.admin_audit_log (action, admin_id, target_user_id, details)
  VALUES ('delete_user', auth.uid(), p_user_id,
          jsonb_build_object('deleted_user_name', v_name, 'deleted_user_email', v_email, 'deleted_user_role', v_role,
                             'deleted_notes_count', v_notes, 'deleted_flashcards_count', v_cards,
                             'total_content_deleted', v_notes + v_cards,
                             'provenance_rows_detached', v_detached,
                             'auth_deletion_status', 'manual_required', 'via', 'admin_delete_user_data'));

  -- The only foreign key to profiles(id) with no delete rule: detach, do not delete, the batch-source history.
  UPDATE flashcard_batch_provenance SET created_by = NULL WHERE created_by = p_user_id;

  DELETE FROM study_group_members WHERE user_id = p_user_id;
  DELETE FROM profile_courses    WHERE user_id = p_user_id;
  DELETE FROM reviews            WHERE user_id = p_user_id;
  DELETE FROM flashcards         WHERE user_id = p_user_id;
  DELETE FROM flashcard_decks    WHERE user_id = p_user_id;
  DELETE FROM notes              WHERE user_id = p_user_id;
  DELETE FROM profiles           WHERE id      = p_user_id;
END;
$function$;
