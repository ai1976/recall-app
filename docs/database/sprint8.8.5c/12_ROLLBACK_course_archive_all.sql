-- Name: [SCHEMA] ROLLBACK - remove ALL of Sprint 8.8.5c's database changes (03-07, 10)
-- Status: EMERGENCY ONLY. Do not run unless something in production broke and the operator decides to revert.
-- Description: Undoes, in a safe order, everything 8.8.5c added. Run the PARTS you need, top to bottom:
--   PART A restores every archived enrollment to 'active' (this undoes the backfill AND any live archival) - the
--          archive columns are cleared by trg_enrollment_clear_archive, which therefore must still exist.
--   PART B drops the course-change trigger and functions (the behaviour change).
--   PART C drops the bulk RPCs (independent of everything else).
--   PART D removes the schema additions - only AFTER Part A, or the CHECK on status would fail.
--   Because the frontend will call preview_course_change / get_course_archived_my_cards / the bulk RPCs, revert or
--   hide those UI parts first, or they will show errors.

-- ── PART A: undo all archival ────────────────────────────────────────────────
UPDATE public.my_cards_enrollment SET status = 'active' WHERE status = 'course_archived';

-- ── PART B: course-change behaviour ──────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_course_change_archive_restore ON public.profiles;
DROP FUNCTION IF EXISTS public.fn_course_change_archive_restore();
DROP FUNCTION IF EXISTS public.preview_course_change(text);
DROP FUNCTION IF EXISTS public.get_course_archived_my_cards(uuid);
DROP FUNCTION IF EXISTS public.course_change_affected(uuid, text, text);

-- ── PART C: bulk RPCs ────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.bulk_pause_my_cards(uuid, uuid[]);
DROP FUNCTION IF EXISTS public.bulk_resume_my_cards(uuid, uuid[]);
DROP FUNCTION IF EXISTS public.bulk_remove_from_my_cards(uuid, uuid[]);

-- ── PART D: schema (only after Part A) ───────────────────────────────────────
ALTER TABLE public.my_cards_enrollment DROP CONSTRAINT IF EXISTS my_cards_enrollment_archive_consistency;
DROP TRIGGER IF EXISTS trg_enrollment_clear_archive ON public.my_cards_enrollment;
DROP FUNCTION IF EXISTS public.fn_enrollment_clear_archive_on_reactivate();
DROP INDEX IF EXISTS public.idx_my_cards_enrollment_user_archived;
ALTER TABLE public.my_cards_enrollment DROP CONSTRAINT IF EXISTS my_cards_enrollment_status_check;
ALTER TABLE public.my_cards_enrollment
  ADD CONSTRAINT my_cards_enrollment_status_check CHECK (status = ANY (ARRAY['active'::text, 'removed'::text]));
ALTER TABLE public.my_cards_enrollment DROP COLUMN IF EXISTS archived_at, DROP COLUMN IF EXISTS archived_course;
