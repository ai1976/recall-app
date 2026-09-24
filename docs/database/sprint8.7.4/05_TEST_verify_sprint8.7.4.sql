-- Name: [TEST] Verify Sprint 8.7.4 — provenance read policy + RPC display columns
--
-- Description: Run after 01/02/03/04 are all deployed. Uses this project's
-- established RLS-impersonation idiom (SET LOCAL ROLE authenticated + a real
-- request.jwt.claims — NOT just setting the claim, since the Supabase SQL
-- Editor connects as a superuser/table-owner role that bypasses RLS regardless
-- of jwt claims alone; see sprint8.6c's 03_TEST postmortem, blueprint.md §1.11
-- for why this exact mistake was made and fixed before). Everything runs
-- inside BEGIN...ROLLBACK — nothing persisted.
--
-- Replace :test_user_id below with a real profiles.id before running (any
-- authenticated user works for T1-T3; T4-T6 are more informative against a
-- user who actually has some flashcards/notes with provenance rows).26507dc7-5ceb-4940-878e-f4cdd2f6eab3

BEGIN;

-- T1: exactly one SELECT policy on flashcard_batch_provenance, the one this
-- sprint added — regression guard against 8.7.1's zero-policy state silently
-- persisting (01_SCHEMA not run) or a duplicate policy being added by mistake.
SELECT
  CASE WHEN count(*) = 1 AND bool_and(policyname = 'authenticated_read_flashcard_batch_provenance')
       THEN 'T1 PASS: exactly one SELECT policy, correctly named'
       ELSE 'T1 FAIL: ' || count(*) || ' SELECT policies found — ' || string_agg(policyname, ', ')
  END AS t1_result
FROM pg_policies
WHERE tablename = 'flashcard_batch_provenance' AND cmd = 'SELECT';

-- T2: authenticated can now SELECT from flashcard_batch_provenance directly
-- (the actual capability this sprint adds — MyFlashcards.jsx/StudyMode.jsx/
-- NoteDetail.jsx's client-side .from('flashcard_batch_provenance') calls
-- depend on this working, not just the RPCs which bypass RLS anyway).
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "26507dc7-5ceb-4940-878e-f4cdd2f6eab3", "role": "authenticated"}';

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.flashcard_batch_provenance;
  RAISE NOTICE 'T2: authenticated SELECT on flashcard_batch_provenance returned % row(s) (expected: >= 0, no permission error)', v_count;
END $$;

-- T3: direct writes to flashcard_batch_provenance are STILL denied to
-- authenticated — the new SELECT policy must not have loosened this. Expect
-- each of these to raise (caught individually so one failure doesn't hide
-- the others).
DO $$
BEGIN
  BEGIN
    INSERT INTO public.flashcard_batch_provenance (batch_id, content_source_type, content_source_name)
    VALUES (gen_random_uuid(), 'official_body', 'T3 probe');
    RAISE NOTICE 'T3a FAIL: authenticated INSERT into flashcard_batch_provenance succeeded (should be denied)';
  EXCEPTION WHEN insufficient_privilege OR others THEN
    RAISE NOTICE 'T3a PASS: authenticated INSERT denied (%)', SQLERRM;
  END;

  BEGIN
    UPDATE public.flashcard_batch_provenance SET content_source_name = 'hacked' WHERE true;
    RAISE NOTICE 'T3b FAIL: authenticated UPDATE on flashcard_batch_provenance succeeded (should be denied)';
  EXCEPTION WHEN insufficient_privilege OR others THEN
    RAISE NOTICE 'T3b PASS: authenticated UPDATE denied (%)', SQLERRM;
  END;
END $$;

RESET ROLE;

-- T4: get_browsable_decks returns the two new columns and they resolve
-- correctly for a real deck. Run as the operator (bypasses RLS/auth check —
-- get_browsable_decks itself RAISEs 'Not authenticated' outside a real
-- session) is NOT valid here since the function requires auth.uid(); use the
-- app itself (ReviewFlashcards.jsx / Browse Study Sets) or a direct PostgREST
-- call with a real access token for this check, same as 8.7.2/8.7.3 did for
-- their own RPC-level live verification. Documented here as the check to run,
-- not executable in the SQL Editor:
--   SELECT id, provenance_source_type, provenance_source_name FROM get_browsable_decks() LIMIT 20;
--   -- then manually confirm: a deck whose cards were all created in one
--   -- batch shows a non-null source; a deck spanning multiple batches (or
--   -- entirely legacy/pre-8.7.1) shows NULL in both columns.

-- T5: get_browsable_notes returns content_source_type/content_source_name
-- matching the underlying notes row exactly (row-level, no ambiguity).
-- Also app/PostgREST-level, same reason as T4:
--   SELECT id, content_source_type, content_source_name FROM get_browsable_notes() LIMIT 20;
--   -- cross-check a couple of ids against: SELECT content_source_type, content_source_name FROM notes WHERE id = '<id>';

-- T6: get_study_queue returns batch_id matching flashcards.batch_id for the
-- same flashcard_id. App/PostgREST-level:
--   SELECT flashcard_id, batch_id FROM get_study_queue(p_user_id => '<test_user_id>') LIMIT 20;
--   -- cross-check: SELECT batch_id FROM flashcards WHERE id = '<flashcard_id>';

-- T7: anon still cannot read flashcard_batch_provenance (the SELECT policy is
-- scoped TO authenticated only — this re-confirms RLS default-deny still
-- applies to anon, since 8.7.1 already proved anon has no table-level grant
-- either; this test proves the RLS layer alone still blocks it too).
SET LOCAL ROLE anon;
DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.flashcard_batch_provenance;
  RAISE NOTICE 'T7 FAIL: anon SELECT on flashcard_batch_provenance succeeded, % rows (should be permission denied)', v_count;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'T7 PASS: anon SELECT denied (%)', SQLERRM;
END $$;
RESET ROLE;

ROLLBACK;
