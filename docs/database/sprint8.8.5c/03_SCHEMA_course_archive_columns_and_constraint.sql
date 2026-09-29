-- Name: [SCHEMA] Sprint 8.8.5c - course-archive state on my_cards_enrollment
-- Description: Adds the third enrollment state `course_archived` plus the two nullable columns that say which
--   course a row was archived FROM and when. Approved design (D-44, 29/09/2026):
--     status IN ('active','removed','course_archived'), archived_course text NULL, archived_at timestamptz NULL.
--   Why a status value (not an independent flag): every live reader compares status = 'active' or = 'removed'
--   (verified in the live function bodies, 02_DIAGNOSTIC block 2), so an archived row is excluded from My Study,
--   Review, Practice counts and History-Removed automatically - fail closed. Pause/Mastered live on `reviews`, which
--   archival never touches, so restoring the enrollment to 'active' preserves them without any reconstruction.
--   Also adds:
--     * a CHECK that ties the two columns to the status (both set iff status = 'course_archived'), and
--     * BEFORE UPDATE trigger trg_enrollment_clear_archive: whenever a row LEAVES 'course_archived' (e.g. the
--       existing add_to_my_cards / add_batch_to_my_cards ON CONFLICT ... SET status = 'active' re-add paths) the
--       archive columns are cleared automatically. This means those two live functions need NO patch, and the
--       CHECK can never be violated by them.
--   Safe on existing data: all current rows are 'active'/'removed' with NULL archive columns.
--   Run on its own. Nothing here changes behaviour until 05 (the course-change trigger) is deployed.

ALTER TABLE public.my_cards_enrollment
  ADD COLUMN IF NOT EXISTS archived_course text,
  ADD COLUMN IF NOT EXISTS archived_at     timestamptz;

CREATE OR REPLACE FUNCTION public.fn_enrollment_clear_archive_on_reactivate()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
BEGIN
  NEW.archived_course := NULL;
  NEW.archived_at     := NULL;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_enrollment_clear_archive ON public.my_cards_enrollment;
CREATE TRIGGER trg_enrollment_clear_archive
  BEFORE UPDATE ON public.my_cards_enrollment
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM 'course_archived'
        AND (OLD.archived_course IS NOT NULL OR OLD.archived_at IS NOT NULL))
  EXECUTE FUNCTION public.fn_enrollment_clear_archive_on_reactivate();

ALTER TABLE public.my_cards_enrollment DROP CONSTRAINT IF EXISTS my_cards_enrollment_status_check;
ALTER TABLE public.my_cards_enrollment
  ADD CONSTRAINT my_cards_enrollment_status_check
  CHECK (status = ANY (ARRAY['active'::text, 'removed'::text, 'course_archived'::text]));

ALTER TABLE public.my_cards_enrollment DROP CONSTRAINT IF EXISTS my_cards_enrollment_archive_consistency;
ALTER TABLE public.my_cards_enrollment
  ADD CONSTRAINT my_cards_enrollment_archive_consistency
  CHECK (
    (status = 'course_archived' AND archived_course IS NOT NULL AND archived_at IS NOT NULL)
    OR
    (status <> 'course_archived' AND archived_course IS NULL AND archived_at IS NULL)
  );

-- Restore lookup: "rows archived from course X for user U".
CREATE INDEX IF NOT EXISTS idx_my_cards_enrollment_user_archived
  ON public.my_cards_enrollment (user_id, archived_course)
  WHERE status = 'course_archived';
