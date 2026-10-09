-- Name: [SCHEMA] T-002 B-05 ROLLBACK (v1) - remove the flashcards and notes course triggers, the function and the composite keys
--
-- Description: PERSISTENT DDL, the undo of B-05_SCHEMA_flashcards-notes-course-derive_v1.sql. Run as ONE selection AFTER the B-06a and any later rollback and BEFORE B-04a_ROLLBACK (undo order for the stream: B-06a,
-- B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01). It proves that the objects it drops are the B-05 ones, drops the two composite keys, the two triggers and the function, and raises unless the end state is exact.
-- Values the triggers already derived stay as they are (they equal the subject's discipline). Existing columns, rows and the older triggers are not touched. Not run unless the Founder decides to undo B-05.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.flashcards, public.notes IN SHARE ROW EXCLUSIVE MODE;

DO $guard$
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  IF (SELECT count(*) FROM pg_trigger t WHERE t.tgname IN ('trg_flashcards_course_derive_guard', 'trg_notes_course_derive_guard') AND NOT t.tgisinternal
        AND t.tgrelid IN ('public.flashcards'::regclass, 'public.notes'::regclass)
        AND pg_get_triggerdef(t.oid) IN ('CREATE TRIGGER trg_flashcards_course_derive_guard BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_course_derive_guard()', 'CREATE TRIGGER trg_notes_course_derive_guard BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_course_derive_guard()')) <> 2
     OR NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_course_derive_guard()') AND p.prosecdef AND pg_get_userbyid(p.proowner) = 'postgres')
     OR (SELECT count(*) FROM pg_constraint WHERE conname IN ('flashcards_discipline_subject_fkey', 'notes_discipline_subject_fkey') AND contype = 'f' AND NOT convalidated) <> 2 THEN
    RAISE EXCEPTION 'B-05 ROLLBACK stopped: the triggers, function or composite keys are not the B-05 objects (or are already removed)';
  END IF;
END
$guard$;

ALTER TABLE public.flashcards DROP CONSTRAINT flashcards_discipline_subject_fkey;
ALTER TABLE public.notes DROP CONSTRAINT notes_discipline_subject_fkey;
DROP TRIGGER trg_flashcards_course_derive_guard ON public.flashcards;
DROP TRIGGER trg_notes_course_derive_guard ON public.notes;
DROP FUNCTION public.fn_course_derive_guard();

DO $postcheck$
BEGIN
  IF (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.flashcards'::regclass AND NOT tgisinternal) <> 7
     OR (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.notes'::regclass AND NOT tgisinternal) <> 6
     OR to_regprocedure('public.fn_course_derive_guard()') IS NOT NULL
     OR EXISTS (SELECT 1 FROM pg_constraint WHERE conname IN ('flashcards_discipline_subject_fkey', 'notes_discipline_subject_fkey')) THEN
    RAISE EXCEPTION 'B-05 ROLLBACK stopped: the end state is not the pre-B-05 state (7 flashcards triggers, 6 notes triggers, no function, no composite key); nothing is applied';
  END IF;
END
$postcheck$;

SELECT (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.flashcards'::regclass AND NOT tgisinternal) AS flashcards_triggers_expected_7,
       (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.notes'::regclass AND NOT tgisinternal) AS notes_triggers_expected_6,
       to_regprocedure('public.fn_course_derive_guard()') IS NULL AS function_removed;
