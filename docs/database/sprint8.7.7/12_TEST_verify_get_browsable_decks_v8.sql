-- [TEST] Verify get_browsable_decks v8 (matching_card_count) - invariants, all rolled back
-- Description: Run AFTER 11_FUNCTIONS. Everything is inside BEGIN...ROLLBACK (temp tables only; no persistent write).
--   Impersonates one real user by setting request.jwt.claims so auth.uid() resolves (the function is SECURITY DEFINER
--   and RAISEs 'Not authenticated' otherwise). Change v_email below to a user who actually has visible content;
--   a user with no decks makes the test FAIL as "vacuous" rather than pass silently.
--   Produces ONE result grid at the end (test, verdict, detail). Every row must be PASS (T0 is INFO, T7 may be INFO).
--   No persistent DDL is mixed into this file (Supabase SQL Editor runs one transaction).
--
--   INVARIANTS (exact wording):
--   T1  exactly one get_browsable_decks overload in public; it returns matching_card_count as its LAST column;
--       SECURITY DEFINER = true; search_path = public, extensions. The ACL is printed for comparison with 10_DIAGNOSTIC.
--   T2  every question_type present in flashcards is one of the 9 documented values (so T5's partition covers all cards).
--   T3  no filter: at least one deck returned, and matching_card_count = card_count for EVERY returned deck.
--   T4  filter = t (each of the 9 types): every returned deck satisfies 1 <= matching_card_count <= card_count, and
--       the deck also appears in the unfiltered result.
--   T5  partition: for EVERY deck in the unfiltered result, the sum over all 9 types of matching_card_count
--       (0 where the deck is not returned for that type) equals that deck's card_count. This is the invariant that
--       removes the double counting.
--   T6  reconciliation with row-level security: for every (deck, type) returned, matching_card_count equals the number
--       of flashcards of that type in the deck's 5-grouping-column bucket that the same user can see under RLS
--       (SET LOCAL ROLE authenticated). Any mismatch must be investigated before the frontend is deployed.
--   T7  coverage: reports how many cards owned by other users are private (hidden from this viewer), i.e. whether
--       T6 actually exercised the "do not count what the viewer cannot see" rule; INFO if there are none.

BEGIN;

CREATE TEMP TABLE v8_results (test text, verdict text, detail text);
GRANT ALL ON v8_results TO authenticated;

DO $$
DECLARE
  v_email text := 'anandmore@outlook.com';   -- <<< change to a user with visible content if T3 reports vacuous
  v_uid uuid; v_role text;
BEGIN
  SELECT id, role INTO v_uid, v_role FROM public.profiles WHERE email = v_email;
  IF v_uid IS NULL THEN
    INSERT INTO v8_results VALUES ('T0','FAIL','test user not found: '||v_email);
    RAISE EXCEPTION 'test user not found';
  END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('v8.uid', v_uid::text, true);
  INSERT INTO v8_results VALUES ('T0','INFO','viewer = '||v_email||' (role '||coalesce(v_role,'?')||')');
END $$;

-- T1 signature / flags
DO $$
DECLARE r record; n int;
BEGIN
  SELECT count(*) INTO n FROM pg_proc WHERE proname='get_browsable_decks' AND pronamespace='public'::regnamespace;
  SELECT p.oid, pg_get_function_result(p.oid) AS res, p.prosecdef, p.proconfig, p.proacl::text AS acl INTO r
    FROM pg_proc p WHERE p.proname='get_browsable_decks' AND p.pronamespace='public'::regnamespace LIMIT 1;
  INSERT INTO v8_results VALUES ('T1',
    CASE WHEN n = 1
          AND r.res ~ 'provenance_source_name text, matching_card_count integer\)?$'
          AND r.prosecdef
          AND r.proconfig::text ILIKE '%search_path=public, extensions%'
         THEN 'PASS' ELSE 'FAIL' END,
    'overloads='||n||'; secdef='||r.prosecdef||'; settings='||coalesce(r.proconfig::text,'null')||'; acl='||coalesce(r.acl,'null'));
END $$;

-- T2 all stored question types are in the documented list
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM (SELECT DISTINCT question_type FROM public.flashcards) t
   WHERE question_type NOT IN ('flashcard','mcq','correct_incorrect','theory','case_study_mcq','match_the_following','fitb','concept_card','mcq_multi');
  INSERT INTO v8_results VALUES ('T2', CASE WHEN n=0 THEN 'PASS' ELSE 'FAIL' END, 'undocumented question_type values in flashcards: '||n);
END $$;

-- snapshots (the function is SECURITY DEFINER; auth.uid() comes from the claims set above)
CREATE TEMP TABLE v8_unf AS
  SELECT id, user_id, subject_id, custom_subject, topic_id, custom_topic, card_count, matching_card_count
  FROM public.get_browsable_decks();
CREATE TEMP TABLE v8_f (qt text, id uuid, user_id uuid, subject_id uuid, custom_subject text, topic_id uuid, custom_topic text, card_count int, matching_card_count int);
GRANT ALL ON v8_unf TO authenticated;
GRANT ALL ON v8_f TO authenticated;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['flashcard','mcq','correct_incorrect','theory','case_study_mcq','match_the_following','fitb','concept_card','mcq_multi'] LOOP
    INSERT INTO v8_f
      SELECT t, d.id, d.user_id, d.subject_id, d.custom_subject, d.topic_id, d.custom_topic, d.card_count, d.matching_card_count
      FROM public.get_browsable_decks(t) d;
  END LOOP;
END $$;

-- T3 no filter
DO $$
DECLARE n int; bad int;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE matching_card_count IS DISTINCT FROM card_count) INTO n, bad FROM v8_unf;
  INSERT INTO v8_results VALUES ('T3', CASE WHEN n>0 AND bad=0 THEN 'PASS' ELSE 'FAIL' END,
    'decks='||n||'; rows where matching_card_count <> card_count='||bad||CASE WHEN n=0 THEN ' (VACUOUS: viewer has no decks - change v_email)' ELSE '' END);
END $$;

-- T4 per-type range + membership
DO $$
DECLARE n int; bad_range int; not_in_unf int;
BEGIN
  SELECT count(*),
         count(*) FILTER (WHERE matching_card_count < 1 OR matching_card_count > card_count),
         count(*) FILTER (WHERE id NOT IN (SELECT id FROM v8_unf))
    INTO n, bad_range, not_in_unf FROM v8_f;
  INSERT INTO v8_results VALUES ('T4', CASE WHEN n>0 AND bad_range=0 AND not_in_unf=0 THEN 'PASS' ELSE 'FAIL' END,
    'filtered rows='||n||'; out-of-range='||bad_range||'; not in unfiltered='||not_in_unf);
END $$;

-- T5 partition
DO $$
DECLARE bad int; n int;
BEGIN
  SELECT count(*) INTO n FROM v8_unf;
  SELECT count(*) INTO bad FROM v8_unf u
   WHERE u.card_count IS DISTINCT FROM (SELECT coalesce(sum(f.matching_card_count),0) FROM v8_f f WHERE f.id = u.id);
  INSERT INTO v8_results VALUES ('T5', CASE WHEN n>0 AND bad=0 THEN 'PASS' ELSE 'FAIL' END,
    'decks checked='||n||'; decks where sum over types <> card_count='||bad);
END $$;

-- T6 reconciliation against the RLS-visible recount (viewer role: authenticated)
DO $$
DECLARE n int; bad int;
BEGIN
  SET LOCAL ROLE authenticated;
  SELECT count(*),
         count(*) FILTER (WHERE f.matching_card_count IS DISTINCT FROM (
           SELECT count(*) FROM public.flashcards fc
            WHERE fc.user_id = f.user_id
              AND fc.subject_id IS NOT DISTINCT FROM f.subject_id
              AND fc.topic_id IS NOT DISTINCT FROM f.topic_id
              AND fc.custom_subject IS NOT DISTINCT FROM f.custom_subject
              AND fc.custom_topic IS NOT DISTINCT FROM f.custom_topic
              AND fc.question_type = f.qt))
    INTO n, bad FROM v8_f f;
  RESET ROLE;
  INSERT INTO v8_results VALUES ('T6', CASE WHEN n>0 AND bad=0 THEN 'PASS' ELSE 'FAIL' END,
    'deck/type rows reconciled='||n||'; mismatches vs RLS-visible recount='||bad);
END $$;

-- T7 coverage of the hidden-card rule
DO $$
DECLARE hidden int;
BEGIN
  SELECT count(*) INTO hidden FROM public.flashcards
   WHERE visibility = 'private' AND user_id <> current_setting('v8.uid')::uuid;
  INSERT INTO v8_results VALUES ('T7', CASE WHEN hidden>0 THEN 'PASS' ELSE 'INFO' END,
    'private cards owned by other users (must be excluded from the counts): '||hidden);
END $$;

SELECT test, verdict, detail FROM v8_results ORDER BY test;

ROLLBACK;
